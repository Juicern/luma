package httpapi

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/Juicern/luma/internal/app"
)

func NewRouter(service *app.DocumentService) http.Handler {
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	documentHandler := NewDocumentHandler(service)

	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	api := r.Group("/api/v1")
	{
		documentHandler.RegisterRoutes(api.Group("/documents"))
	}

	return r
}
