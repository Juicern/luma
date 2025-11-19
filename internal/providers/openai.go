package providers

import (
	"context"
	"errors"
	"fmt"
	"strings"

	openai "github.com/sashabaranov/go-openai"
)

type OpenAIClient struct {
	baseURL string
}

func NewOpenAIClient(baseURL string) *OpenAIClient {
	return &OpenAIClient{baseURL: baseURL}
}

func (c *OpenAIClient) Generate(ctx context.Context, req GenerateRequest) (string, error) {
	if req.APIKey == "" {
		return "", errors.New("missing OpenAI API key")
	}

	cfg := openai.DefaultConfig(req.APIKey)
	if c.baseURL != "" {
		cfg.BaseURL = c.baseURL
	}

	client := openai.NewClientWithConfig(cfg)

	userContent := composeUserContent(req)

	resp, err := client.CreateChatCompletion(ctx, openai.ChatCompletionRequest{
		Model: req.Model,
		Messages: []openai.ChatCompletionMessage{
			{
				Role:    openai.ChatMessageRoleSystem,
				Content: req.SystemPrompt,
			},
			{
				Role:    openai.ChatMessageRoleUser,
				Content: userContent,
			},
		},
		Temperature: 0.7,
	})
	if err != nil {
		return "", err
	}
	if len(resp.Choices) == 0 {
		return "", errors.New("openai returned no choices")
	}
	return resp.Choices[0].Message.Content, nil
}

func composeUserContent(req GenerateRequest) string {
	var b strings.Builder
	if req.PresetPrompt != "" {
		fmt.Fprintf(&b, "Preset instructions:\n%s\n\n", req.PresetPrompt)
	}
	if req.TemporaryPrompt != "" {
		fmt.Fprintf(&b, "Temporary prompt:\n%s\n\n", req.TemporaryPrompt)
	}
	if req.ContextText != "" {
		fmt.Fprintf(&b, "Clipboard/context:\n%s\n\n", req.ContextText)
	}
	fmt.Fprintf(&b, "Please rewrite the following content:\n%s", req.Content)
	return b.String()
}
