package service

import (
	"context"
	"database/sql"

	"github.com/Juicern/luma/internal/domain"
	"github.com/Juicern/luma/internal/providers"
	"github.com/Juicern/luma/internal/repository"
)

type SessionInput struct {
	PresetID         string
	ProviderName     string
	Model            string
	TemporaryPrompt  *string
	ContextText      *string
	ClipboardEnabled bool
}

type SessionDetail struct {
	Session      domain.Session
	Preset       domain.PromptPreset
	SystemPrompt domain.SystemPrompt
	Messages     []domain.Message
}

type SessionService struct {
	sessions *repository.SessionRepository
	messages *repository.MessageRepository
	prompts  *PromptService
	apiKeys  *APIKeyService
	llms     *providers.Registry
}

func NewSessionService(
	sessions *repository.SessionRepository,
	messages *repository.MessageRepository,
	prompts *PromptService,
	apiKeys *APIKeyService,
	llms *providers.Registry,
) *SessionService {
	return &SessionService{
		sessions: sessions,
		messages: messages,
		prompts:  prompts,
		apiKeys:  apiKeys,
		llms:     llms,
	}
}

func (s *SessionService) CreateSession(ctx context.Context, input SessionInput) (domain.Session, error) {
	preset, err := s.prompts.GetPreset(ctx, input.PresetID)
	if err != nil {
		return domain.Session{}, err
	}

	systemPrompt, err := s.prompts.GetSystemPrompt(ctx)
	if err != nil {
		return domain.Session{}, err
	}

	session := domain.Session{
		PresetID:         preset.ID,
		ProviderName:     input.ProviderName,
		Model:            input.Model,
		TemporaryPrompt:  input.TemporaryPrompt,
		ContextText:      input.ContextText,
		ClipboardEnabled: input.ClipboardEnabled,
		SystemPromptID:   systemPrompt.ID,
	}

	return s.sessions.Create(ctx, session)
}

func (s *SessionService) ListSessions(ctx context.Context, limit int) ([]domain.Session, error) {
	return s.sessions.List(ctx, limit)
}

func (s *SessionService) GetSessionDetail(ctx context.Context, id string) (SessionDetail, error) {
	session, err := s.sessions.Get(ctx, id)
	if err != nil {
		return SessionDetail{}, err
	}
	preset, err := s.prompts.GetPreset(ctx, session.PresetID)
	if err != nil {
		return SessionDetail{}, err
	}
	systemPrompt, err := s.prompts.GetSystemPrompt(ctx)
	if err != nil {
		return SessionDetail{}, err
	}
	messages, err := s.messages.ListBySession(ctx, session.ID)
	if err != nil {
		return SessionDetail{}, err
	}

	return SessionDetail{
		Session:      session,
		Preset:       preset,
		SystemPrompt: systemPrompt,
		Messages:     messages,
	}, nil
}

func (s *SessionService) AddContentMessage(ctx context.Context, sessionID, rawText string) (domain.Message, error) {
	_, err := s.sessions.Get(ctx, sessionID)
	if err != nil {
		return domain.Message{}, err
	}
	msg := domain.Message{
		SessionID: sessionID,
		Type:      domain.MessageTypeContent,
		RawText:   rawText,
	}
	return s.messages.Create(ctx, msg)
}

func (s *SessionService) RewriteMessage(ctx context.Context, sessionID, messageID string) (domain.Message, error) {
	session, err := s.sessions.Get(ctx, sessionID)
	if err != nil {
		return domain.Message{}, err
	}

	contentMsg, err := s.messages.Get(ctx, messageID)
	if err != nil {
		return domain.Message{}, err
	}

	if contentMsg.Type != domain.MessageTypeContent {
		return domain.Message{}, sql.ErrNoRows
	}

	preset, err := s.prompts.GetPreset(ctx, session.PresetID)
	if err != nil {
		return domain.Message{}, err
	}
	systemPrompt, err := s.prompts.GetSystemPrompt(ctx)
	if err != nil {
		return domain.Message{}, err
	}

	client, ok := s.llms.Client(session.ProviderName)
	if !ok {
		return domain.Message{}, ErrProviderNotSupported
	}

	apiKey, err := s.apiKeys.GetDecrypted(ctx, session.ProviderName)
	if err != nil {
		return domain.Message{}, ErrMissingAPIKey
	}

	req := providers.GenerateRequest{
		ProviderName:    session.ProviderName,
		Model:           session.Model,
		SystemPrompt:    systemPrompt.PromptText,
		PresetPrompt:    preset.PromptText,
		TemporaryPrompt: deref(session.TemporaryPrompt),
		ContextText:     deref(session.ContextText),
		Content:         contentMsg.RawText,
		APIKey:          apiKey,
	}

	result, err := client.Generate(ctx, req)
	if err != nil {
		return domain.Message{}, err
	}

	msg := domain.Message{
		SessionID:       session.ID,
		Type:            domain.MessageTypeRewrite,
		RawText:         contentMsg.RawText,
		TransformedText: &result,
	}

	return s.messages.Create(ctx, msg)
}

func deref(ptr *string) string {
	if ptr == nil {
		return ""
	}
	return *ptr
}
