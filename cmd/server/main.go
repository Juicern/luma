package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/Juicern/luma/internal/app"
	"github.com/Juicern/luma/internal/config"
	"github.com/Juicern/luma/internal/httpapi"
	"github.com/Juicern/luma/internal/server"
)

func main() {
	cfg := config.Load()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	service := app.NewDocumentService(logger)
	handler := httpapi.NewRouter(service)
	srv := server.New(cfg, handler, logger)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if err := srv.Run(ctx); err != nil {
		logger.Error("server stopped with error", slog.Any("error", err))
		os.Exit(1)
	}
}
