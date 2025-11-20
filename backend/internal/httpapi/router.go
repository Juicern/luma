package httpapi

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/Juicern/luma/internal/service"
)

func NewRouter(
	userService *service.UserService,
	authService *service.AuthService,
	promptService *service.PromptService,
	apiKeyService *service.APIKeyService,
	transcriptionService *service.TranscriptionService,
	composerService *service.ComposeService,
	logger *slog.Logger,
) http.Handler {
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	api := &API{
		users:         userService,
		auth:          authService,
		prompts:       promptService,
		keys:          apiKeyService,
		transcription: transcriptionService,
		composer:      composerService,
		logger:        logger,
	}

	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	v1 := r.Group("/api/v1")
	api.registerRoutes(v1)

	return r
}
