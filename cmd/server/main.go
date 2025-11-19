package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
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

	db, err := storage.NewDatabase(cfg.Database)
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
	sessionRepo := repository.NewSessionRepository(db)
	messageRepo := repository.NewMessageRepository(db)

	promptService := service.NewPromptService(systemRepo, presetRepo)
	if _, err := promptService.EnsureDefaultSystemPrompt(ctx); err != nil {
		logger.Error("failed to initialize system prompt", slog.Any("error", err))
		os.Exit(1)
	}

	apiKeyService := service.NewAPIKeyService(apiKeyRepo, cfg.Security.EncryptionKey)
	llmRegistry := providers.NewRegistry()
	llmRegistry.Register("openai", providers.EchoClient{})
	llmRegistry.Register("gemini", providers.EchoClient{})

	sessionService := service.NewSessionService(sessionRepo, messageRepo, promptService, apiKeyService, llmRegistry)
	transcriptionService := service.NewTranscriptionService()

	handler := httpapi.NewRouter(promptService, sessionService, apiKeyService, transcriptionService, logger)
	srv := server.New(cfg, handler, logger)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if err := srv.Run(ctx); err != nil {
		logger.Error("server stopped with error", slog.Any("error", err))
		os.Exit(1)
	}
}
