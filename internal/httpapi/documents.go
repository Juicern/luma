package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Juicern/luma/internal/app"
)

type DocumentHandler struct {
	service *app.DocumentService
	logger  Logger
}

func NewDocumentHandler(service *app.DocumentService, logger Logger) *DocumentHandler {
	return &DocumentHandler{service: service, logger: logger}
}

func (h *DocumentHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.listDocuments)
	r.Post("/", h.createDocument)
	r.Get("/{id}", h.getDocument)
	r.Put("/{id}", h.updateDocument)
	r.Delete("/{id}", h.deleteDocument)
	return r
}

func (h *DocumentHandler) listDocuments(w http.ResponseWriter, r *http.Request) {
	docs := h.service.List()
	writeJSON(w, http.StatusOK, docs)
}

func (h *DocumentHandler) createDocument(w http.ResponseWriter, r *http.Request) {
	var payload documentPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON payload")
		return
	}

	if err := payload.Validate(); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	doc := h.service.Create(payload.Title, payload.Content)
	writeJSON(w, http.StatusCreated, doc)
}

func (h *DocumentHandler) getDocument(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	doc, err := h.service.Get(id)
	if err != nil {
		handleDocumentError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, doc)
}

func (h *DocumentHandler) updateDocument(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var payload documentPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON payload")
		return
	}

	if err := payload.Validate(); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	doc, err := h.service.Update(id, payload.Title, payload.Content)
	if err != nil {
		handleDocumentError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, doc)
}

func (h *DocumentHandler) deleteDocument(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.service.Delete(id); err != nil {
		handleDocumentError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
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

func handleDocumentError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, app.ErrDocumentNotFound):
		writeError(w, http.StatusNotFound, err.Error())
	default:
		writeError(w, http.StatusInternalServerError, "internal error")
	}
}
