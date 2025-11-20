package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/Juicern/luma/internal/config"
	"github.com/Juicern/luma/internal/httpapi"
	"github.com/Juicern/luma/internal/providers"
	"github.com/Juicern/luma/internal/repository"
	"github.com/Juicern/luma/internal/server"
	"github.com/Juicern/luma/internal/service"
	"github.com/Juicern/luma/internal/storage"
)

func main() {
	cfg := config.Load()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	ctx := context.Background()

	db, err := storage.NewDatabase(ctx, cfg.Database)
	if err != nil {
		logger.Error("failed to open database", slog.Any("error", err))
		os.Exit(1)
	}
	defer db.Close()

	if err := storage.RunMigrations(ctx, db); err != nil {
		logger.Error("failed to run migrations", slog.Any("error", err))
		os.Exit(1)
	}

	systemRepo := repository.NewSystemPromptRepository(db)
	presetRepo := repository.NewPromptPresetRepository(db)
	apiKeyRepo := repository.NewAPIKeyRepository(db)
	userSessionRepo := repository.NewUserSessionRepository(db)
	userRepo := repository.NewUserRepository(db)

	promptService := service.NewPromptService(systemRepo, presetRepo)
	if _, err := promptService.EnsureDefaultSystemPrompt(ctx); err != nil {
		logger.Error("failed to initialize system prompt", slog.Any("error", err))
		os.Exit(1)
	}

	userService := service.NewUserService(userRepo)
	authService := service.NewAuthService(userRepo, userSessionRepo)
	apiKeyService := service.NewAPIKeyService(apiKeyRepo, cfg.Security.EncryptionKey)
	llmRegistry := providers.NewRegistry()
	llmRegistry.Register("openai", providers.NewOpenAIClient(providerBaseURL(cfg, "openai")))
	llmRegistry.Register("gemini", providers.EchoClient{})

	transcriptionService := service.NewTranscriptionService(apiKeyService, providerBaseMap(cfg))

	handler := httpapi.NewRouter(userService, authService, promptService, apiKeyService, transcriptionService, logger)
	srv := server.New(cfg, handler, logger)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if err := srv.Run(ctx); err != nil {
		logger.Error("server stopped with error", slog.Any("error", err))
		os.Exit(1)
	}
}

func providerBaseURL(cfg config.Config, name string) string {
	for _, provider := range cfg.Providers {
		if strings.EqualFold(provider.Name, name) {
			return provider.BaseURL
		}
	}
	return ""
}

func providerBaseMap(cfg config.Config) map[string]string {
	m := make(map[string]string)
	for _, provider := range cfg.Providers {
		m[strings.ToLower(provider.Name)] = provider.BaseURL
	}
	return m
}
