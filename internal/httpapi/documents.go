package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/Juicern/luma/internal/app"
)

type DocumentHandler struct {
	service *app.DocumentService
}

func NewDocumentHandler(service *app.DocumentService) *DocumentHandler {
	return &DocumentHandler{service: service}
}

func (h *DocumentHandler) RegisterRoutes(r *gin.RouterGroup) {
	r.GET("/", h.listDocuments)
	r.POST("/", h.createDocument)
	r.GET("/:id", h.getDocument)
	r.PUT("/:id", h.updateDocument)
	r.DELETE("/:id", h.deleteDocument)
}

func (h *DocumentHandler) listDocuments(c *gin.Context) {
	docs := h.service.List()
	c.JSON(http.StatusOK, docs)
}

func (h *DocumentHandler) createDocument(c *gin.Context) {
	payload, err := decodeDocumentPayload(c)
	if err != nil {
		return
	}

	doc := h.service.Create(payload.Title, payload.Content)
	c.JSON(http.StatusCreated, doc)
}

func (h *DocumentHandler) getDocument(c *gin.Context) {
	id := c.Param("id")
	doc, err := h.service.Get(id)
	if err != nil {
		handleDocumentError(c, err)
		return
	}

	c.JSON(http.StatusOK, doc)
}

func (h *DocumentHandler) updateDocument(c *gin.Context) {
	id := c.Param("id")
	payload, err := decodeDocumentPayload(c)
	if err != nil {
		return
	}

	doc, err := h.service.Update(id, payload.Title, payload.Content)
	if err != nil {
		handleDocumentError(c, err)
		return
	}

	c.JSON(http.StatusOK, doc)
}

func (h *DocumentHandler) deleteDocument(c *gin.Context) {
	id := c.Param("id")
	if err := h.service.Delete(id); err != nil {
		handleDocumentError(c, err)
		return
	}

	c.Status(http.StatusNoContent)
}

type documentPayload struct {
	Title   string `json:"title"`
	Content string `json:"content"`
}

func (p documentPayload) Validate() error {
	if p.Title == "" {
		return errors.New("title is required")
	}
	if p.Content == "" {
		return errors.New("content is required")
	}
	return nil
}

func decodeDocumentPayload(c *gin.Context) (documentPayload, error) {
	var payload documentPayload
	if err := json.NewDecoder(c.Request.Body).Decode(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid JSON payload"})
		return documentPayload{}, err
	}

	if err := payload.Validate(); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return documentPayload{}, err
	}

	return payload, nil
}

func handleDocumentError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, app.ErrDocumentNotFound):
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
	}
}
