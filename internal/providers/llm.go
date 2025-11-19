package providers

import (
	"context"
	"fmt"
	"strings"
)

type GenerateRequest struct {
	ProviderName    string
	Model           string
	SystemPrompt    string
	PresetPrompt    string
	TemporaryPrompt string
	ContextText     string
	Content         string
	APIKey          string
}

type LLMClient interface {
	Generate(ctx context.Context, req GenerateRequest) (string, error)
}

type Registry struct {
	clients map[string]LLMClient
}

func NewRegistry() *Registry {
	return &Registry{
		clients: make(map[string]LLMClient),
	}
}

func (r *Registry) Register(provider string, client LLMClient) {
	r.clients[strings.ToLower(provider)] = client
}

func (r *Registry) Client(provider string) (LLMClient, bool) {
	client, ok := r.clients[strings.ToLower(provider)]
	return client, ok
}

type EchoClient struct{}

func (EchoClient) Generate(ctx context.Context, req GenerateRequest) (string, error) {
	response := fmt.Sprintf(
		"[provider=%s model=%s] %s | Preset: %s | Temporary: %s | Context: %s | Content: %s",
		req.ProviderName,
		req.Model,
		req.SystemPrompt,
		req.PresetPrompt,
		req.TemporaryPrompt,
		collapse(req.ContextText),
		req.Content,
	)
	return response, nil
}

func collapse(text string) string {
	if len(text) > 120 {
		return text[:120] + "..."
	}
	return text
}
