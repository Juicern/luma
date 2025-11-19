package server

import (
	"context"
	"log/slog"
	"net"
	"net/http"

	"github.com/Juicern/luma/internal/config"
)

type Server struct {
	cfg     config.Config
	handler http.Handler
	logger  *slog.Logger
}

func New(cfg config.Config, handler http.Handler, logger *slog.Logger) *Server {
	return &Server{
		cfg:     cfg,
		handler: handler,
		logger:  logger,
	}
}

func (s *Server) Run(ctx context.Context) error {
	httpServer := &http.Server{
		Addr:    net.JoinHostPort("", s.cfg.HTTPPort),
		Handler: s.handler,
	}

	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), s.cfg.ShutdownTimeout)
		defer cancel()
		if err := httpServer.Shutdown(shutdownCtx); err != nil {
			s.logger.Error("graceful shutdown failed", slog.Any("error", err))
		}
	}()

	s.logger.Info("server listening", slog.String("port", s.cfg.HTTPPort))
	if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		return err
	}

	return nil
}
