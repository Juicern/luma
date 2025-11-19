package httpapi

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/Juicern/luma/internal/service"
)

func NewRouter(
	userService *service.UserService,
	promptService *service.PromptService,
	sessionService *service.SessionService,
	apiKeyService *service.APIKeyService,
	transcriptionService *service.TranscriptionService,
	logger *slog.Logger,
) http.Handler {
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	api := &API{
		users:         userService,
		prompts:       promptService,
		sessions:      sessionService,
		keys:          apiKeyService,
		transcription: transcriptionService,
		logger:        logger,
	}

	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	v1 := r.Group("/api/v1")
	api.registerRoutes(v1)

	return r
}
