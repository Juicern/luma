package service

import (
	"context"
	"errors"

	"github.com/Juicern/luma/internal/providers"
)

type ComposeService struct {
	prompts  *PromptService
	apiKeys  *APIKeyService
	registry *providers.Registry
}

func NewComposeService(prompts *PromptService, apiKeys *APIKeyService, registry *providers.Registry) *ComposeService {
	return &ComposeService{
		prompts:  prompts,
		apiKeys:  apiKeys,
		registry: registry,
	}
}

type ComposeRequest struct {
	UserID          string
	Provider        string
	Model           string
	SystemPrompt    string
	PresetID        string
	PresetText      string
	TemporaryPrompt string
	ContextText     string
	Content         string
}

func (s *ComposeService) Compose(ctx context.Context, req ComposeRequest) (string, error) {
	if req.Content == "" {
		return "", errors.New("content is required")
	}

	systemPromptText := req.SystemPrompt
	if systemPromptText == "" {
		systemPrompt, err := s.prompts.GetSystemPrompt(ctx)
		if err != nil {
			return "", err
		}
		systemPromptText = systemPrompt.PromptText
	}

	promptText := req.PresetText
	if promptText == "" && req.PresetID != "" {
		preset, err := s.prompts.GetPreset(ctx, req.PresetID)
		if err != nil {
			return "", err
		}
		promptText = preset.PromptText
	}

	client, ok := s.registry.Client(req.Provider)
	if !ok {
		return "", ErrProviderNotSupported
	}

	apiKey, err := s.apiKeys.GetDecrypted(ctx, req.UserID, req.Provider)
	if err != nil {
		return "", err
	}

	model := req.Model
	if model == "" {
		model = "gpt-4o-mini"
	}

	return client.Generate(ctx, providers.GenerateRequest{
		ProviderName:    req.Provider,
		Model:           model,
		SystemPrompt:    systemPromptText,
		PresetPrompt:    promptText,
		TemporaryPrompt: req.TemporaryPrompt,
		ContextText:     req.ContextText,
		Content:         req.Content,
		APIKey:          apiKey,
	})
}
