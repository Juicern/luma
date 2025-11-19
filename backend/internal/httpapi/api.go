package httpapi

import (
	"database/sql"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/Juicern/luma/internal/domain"
	"github.com/Juicern/luma/internal/service"
)

const sessionCookieName = "luma_session"

type API struct {
	users         *service.UserService
	auth          *service.AuthService
	prompts       *service.PromptService
	sessions      *service.SessionService
	keys          *service.APIKeyService
	transcription *service.TranscriptionService
	logger        *slog.Logger
}

func (api *API) registerRoutes(r *gin.RouterGroup) {
	r.POST("/login", api.login)
	r.POST("/logout", api.logout)
	r.GET("/session", api.currentSession)

	r.GET("/users", api.listUsers)
	r.POST("/users", api.createUser)

	r.GET("/system-prompt", api.getSystemPrompt)
	r.PUT("/system-prompt", api.updateSystemPrompt)

	r.GET("/presets", api.listPresets)
	r.POST("/presets", api.createPreset)
	r.PUT("/presets/:id", api.updatePreset)
	r.DELETE("/presets/:id", api.deletePreset)

	r.GET("/api-keys", api.listAPIKeys)
	r.PUT("/api-keys/:provider", api.upsertAPIKey)
	r.DELETE("/api-keys/:provider", api.deleteAPIKey)

	r.POST("/transcriptions", api.createTranscription)

	r.GET("/sessions", api.listSessions)
	r.POST("/sessions", api.createSession)
	r.GET("/sessions/:id", api.getSession)
	r.POST("/sessions/:id/messages", api.addContentMessage)
	r.POST("/sessions/:id/rewrite", api.rewriteMessage)
}

func (api *API) login(c *gin.Context) {
	var payload struct {
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		api.validationError(c, "email and password are required")
		return
	}
	user, session, err := api.auth.Login(c.Request.Context(), payload.Email, payload.Password)
	if err != nil {
		if errors.Is(err, service.ErrInvalidCredentials) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid_credentials"})
			return
		}
		api.handleError(c, err)
		return
	}
	api.setSessionCookie(c, session.Token, session.ExpiresAt)
	c.JSON(http.StatusOK, toUserResponse(user))
}

func (api *API) logout(c *gin.Context) {
	token, err := api.sessionTokenFromCookie(c)
	if err == nil && token != "" {
		_ = api.auth.Logout(c.Request.Context(), token)
	}
	api.clearSessionCookie(c)
	c.Status(http.StatusNoContent)
}

func (api *API) currentSession(c *gin.Context) {
	user, ok := api.requireSessionUser(c)
	if !ok {
		return
	}
	c.JSON(http.StatusOK, toUserResponse(user))
}

func (api *API) getSystemPrompt(c *gin.Context) {
	prompt, err := api.prompts.GetSystemPrompt(c.Request.Context())
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"id":          prompt.ID,
		"prompt_text": prompt.PromptText,
		"updated_at":  prompt.UpdatedAt,
	})
}

func (api *API) updateSystemPrompt(c *gin.Context) {
	var payload struct {
		PromptText string `json:"prompt_text" binding:"required"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		api.validationError(c, "prompt_text is required")
		return
	}
	prompt, err := api.prompts.UpdateSystemPrompt(c.Request.Context(), payload.PromptText)
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, prompt)
}

func (api *API) listPresets(c *gin.Context) {
	presets, err := api.prompts.ListPresets(c.Request.Context())
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, presets)
}

func (api *API) createPreset(c *gin.Context) {
	var payload struct {
		Name       string `json:"name" binding:"required"`
		PromptText string `json:"prompt_text" binding:"required"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		api.validationError(c, "name and prompt_text are required")
		return
	}
	preset, err := api.prompts.CreatePreset(c.Request.Context(), payload.Name, payload.PromptText)
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusCreated, preset)
}

func (api *API) updatePreset(c *gin.Context) {
	var payload struct {
		Name       string `json:"name" binding:"required"`
		PromptText string `json:"prompt_text" binding:"required"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		api.validationError(c, "name and prompt_text are required")
		return
	}
	preset, err := api.prompts.UpdatePreset(c.Request.Context(), c.Param("id"), payload.Name, payload.PromptText)
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, preset)
}

func (api *API) deletePreset(c *gin.Context) {
	if err := api.prompts.DeletePreset(c.Request.Context(), c.Param("id")); err != nil {
		api.handleError(c, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func (api *API) listAPIKeys(c *gin.Context) {
	userID, ok := api.requireUserQuery(c)
	if !ok {
		return
	}
	keys, err := api.keys.ListPlain(c.Request.Context(), userID)
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, keys)
}

func (api *API) upsertAPIKey(c *gin.Context) {
	var payload struct {
		UserID string `json:"user_id"`
		APIKey string `json:"api_key" binding:"required"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		api.validationError(c, "api_key is required")
		return
	}
	userID, ok := api.resolveUserID(c, payload.UserID)
	if !ok {
		return
	}
	if _, err := api.keys.Upsert(c.Request.Context(), userID, c.Param("provider"), payload.APIKey); err != nil {
		api.handleError(c, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func (api *API) deleteAPIKey(c *gin.Context) {
	userID, ok := api.requireUserQuery(c)
	if !ok {
		return
	}
	if err := api.keys.Delete(c.Request.Context(), userID, c.Param("provider")); err != nil {
		api.handleError(c, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func (api *API) listUsers(c *gin.Context) {
	users, err := api.users.List(c.Request.Context())
	if err != nil {
		api.handleError(c, err)
		return
	}
	resp := make([]userResponse, 0, len(users))
	for _, user := range users {
		resp = append(resp, toUserResponse(user))
	}
	c.JSON(http.StatusOK, resp)
}

func (api *API) createUser(c *gin.Context) {
	var payload struct {
		Name     string `json:"name" binding:"required"`
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required,min=8"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		api.validationError(c, "name, email, and password are required")
		return
	}
	user, err := api.users.Create(c.Request.Context(), payload.Name, payload.Email, payload.Password)
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusCreated, toUserResponse(user))
}

func (api *API) createSession(c *gin.Context) {
	var payload struct {
		UserID           string  `json:"user_id"`
		PresetID         string  `json:"preset_id" binding:"required"`
		ProviderName     string  `json:"provider_name" binding:"required"`
		Model            string  `json:"model" binding:"required"`
		TemporaryPrompt  *string `json:"temporary_prompt"`
		ContextText      *string `json:"context_text"`
		ClipboardEnabled bool    `json:"clipboard_enabled"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		api.validationError(c, "preset_id, provider_name, and model are required")
		return
	}
	userID, ok := api.resolveUserID(c, payload.UserID)
	if !ok {
		return
	}
	session, err := api.sessions.CreateSession(c.Request.Context(), service.SessionInput{
		UserID:           userID,
		PresetID:         payload.PresetID,
		ProviderName:     payload.ProviderName,
		Model:            payload.Model,
		TemporaryPrompt:  payload.TemporaryPrompt,
		ContextText:      payload.ContextText,
		ClipboardEnabled: payload.ClipboardEnabled,
	})
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusCreated, session)
}

func (api *API) listSessions(c *gin.Context) {
	userID, ok := api.requireUserQuery(c)
	if !ok {
		return
	}
	limit := 25
	if raw := c.Query("limit"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			limit = parsed
		}
	}
	sessions, err := api.sessions.ListSessions(c.Request.Context(), userID, limit)
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, sessions)
}

func (api *API) getSession(c *gin.Context) {
	detail, err := api.sessions.GetSessionDetail(c.Request.Context(), c.Param("id"))
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, detail)
}

func (api *API) addContentMessage(c *gin.Context) {
	var payload struct {
		RawText string `json:"raw_text" binding:"required"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		api.validationError(c, "raw_text is required")
		return
	}
	msg, err := api.sessions.AddContentMessage(c.Request.Context(), c.Param("id"), payload.RawText)
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusCreated, msg)
}

func (api *API) rewriteMessage(c *gin.Context) {
	var payload struct {
		MessageID string `json:"message_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		api.validationError(c, "message_id is required")
		return
	}
	msg, err := api.sessions.RewriteMessage(c.Request.Context(), c.Param("id"), payload.MessageID)
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, msg)
}

func (api *API) requireUserQuery(c *gin.Context) (string, bool) {
	return api.resolveUserID(c, c.Query("user_id"))
}

type userResponse struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	CreatedAt time.Time `json:"created_at"`
}

func toUserResponse(u domain.User) userResponse {
	return userResponse{
		ID:        u.ID,
		Name:      u.Name,
		Email:     u.Email,
		CreatedAt: u.CreatedAt,
	}
}

func (api *API) createTranscription(c *gin.Context) {
	file, err := c.FormFile("audio")
	if err != nil {
		api.validationError(c, "audio file is required")
		return
	}

	userID, ok := api.resolveUserID(c, c.PostForm("user_id"))
	if !ok {
		return
	}
	provider := c.PostForm("provider")
	if provider == "" {
		provider = "openai"
	}

	f, err := file.Open()
	if err != nil {
		api.handleError(c, err)
		return
	}
	defer f.Close()

	data, err := io.ReadAll(f)
	if err != nil {
		api.handleError(c, err)
		return
	}

	text, err := api.transcription.Transcribe(c.Request.Context(), userID, provider, data, file.Filename)
	if err != nil {
		api.handleError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"transcription": text})
}

func (api *API) handleError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, sql.ErrNoRows):
		c.JSON(http.StatusNotFound, gin.H{"error": "not_found"})
	case errors.Is(err, service.ErrMissingAPIKey):
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing_api_key"})
	case errors.Is(err, service.ErrProviderNotSupported):
		c.JSON(http.StatusBadRequest, gin.H{"error": "provider_not_supported"})
	default:
		api.logger.Error("request failed", slog.Any("error", err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal_error"})
	}
}

func (api *API) validationError(c *gin.Context, msg string) {
	c.JSON(http.StatusBadRequest, gin.H{"error": "validation_error", "message": msg})
}

func (api *API) sessionTokenFromCookie(c *gin.Context) (string, error) {
	cookie, err := c.Request.Cookie(sessionCookieName)
	if err != nil {
		return "", err
	}
	return cookie.Value, nil
}

func (api *API) setSessionCookie(c *gin.Context, token string, expires time.Time) {
	http.SetCookie(c.Writer, &http.Cookie{
		Name:     sessionCookieName,
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Expires:  expires,
	})
}

func (api *API) clearSessionCookie(c *gin.Context) {
	http.SetCookie(c.Writer, &http.Cookie{
		Name:     sessionCookieName,
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		Expires:  time.Unix(0, 0),
		MaxAge:   -1,
	})
}

func (api *API) requireSessionUser(c *gin.Context) (domain.User, bool) {
	token, err := api.sessionTokenFromCookie(c)
	if err != nil || token == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "not_authenticated"})
		return domain.User{}, false
	}
	user, _, err := api.auth.Verify(c.Request.Context(), token)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrSessionExpired):
			c.JSON(http.StatusUnauthorized, gin.H{"error": "session_expired"})
		case errors.Is(err, service.ErrSessionNotFound):
			c.JSON(http.StatusUnauthorized, gin.H{"error": "not_authenticated"})
		default:
			api.handleError(c, err)
		}
		return domain.User{}, false
	}
	return user, true
}

func (api *API) resolveUserID(c *gin.Context, provided string) (string, bool) {
	if provided != "" {
		if _, err := api.users.Get(c.Request.Context(), provided); err != nil {
			api.handleError(c, err)
			return "", false
		}
		return provided, true
	}
	user, ok := api.requireSessionUser(c)
	if !ok {
		return "", false
	}
	return user.ID, true
}
