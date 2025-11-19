SHELL := /bin/bash
APP_NAME := luma
BUILD_DIR := dist
BIN := $(BUILD_DIR)/$(APP_NAME)
PID_FILE := .luma.pid
LOG_DIR := logs
LUMA_SECRET_KEY ?= local-dev-secret

.PHONY: setup build run start stop db migrate release test lint fmt clean

setup: ## Install/update Go modules
	go mod tidy

build: ## Build the server binary
	mkdir -p $(BUILD_DIR)
	go build -o $(BIN) ./cmd/server

run: ## Run the server in the foreground
	mkdir -p data
	LUMA_SECRET_KEY=$(LUMA_SECRET_KEY) go run ./cmd/server

start: build ## Start server in background using built binary
	mkdir -p data $(LOG_DIR)
	@echo "Starting $(APP_NAME) in background..."
	@LUMA_SECRET_KEY=$(LUMA_SECRET_KEY) nohup $(BIN) > $(LOG_DIR)/server.log 2>&1 & echo $$! > $(PID_FILE)
	@echo "PID saved to $(PID_FILE); logs -> $(LOG_DIR)/server.log"

stop: ## Stop background server started via `make start`
	@if [ -f $(PID_FILE) ]; then \
		kill `cat $(PID_FILE)` && rm $(PID_FILE) && echo "Stopped $(APP_NAME)"; \
	else \
		echo "No PID file found. Did you run \`make start\`?"; \
	fi

release: ## Build release binaries for darwin/arm64 and linux/amd64
	mkdir -p $(BUILD_DIR)
	GOOS=darwin GOARCH=arm64 go build -o $(BUILD_DIR)/$(APP_NAME)-darwin-arm64 ./cmd/server
	GOOS=linux GOARCH=amd64 go build -o $(BUILD_DIR)/$(APP_NAME)-linux-amd64 ./cmd/server

fmt: ## Format Go sources
	gofmt -w $(shell find . -name '*.go' -not -path './vendor/*')

lint: ## Basic static analysis
	go vet ./...

test: ## Run unit tests
	go test ./...

db migrate: ## Apply database migrations only
	go run ./cmd/migrate

clean: ## Remove build artifacts and PID/logs
	rm -rf $(BUILD_DIR) $(PID_FILE)
