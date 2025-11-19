package service

import (
	"context"
	"os"
	"strings"

	openai "github.com/sashabaranov/go-openai"
)

type TranscriptionService struct {
	apiKeys  *APIKeyService
	baseURLs map[string]string
}

func NewTranscriptionService(apiKeys *APIKeyService, baseURLs map[string]string) *TranscriptionService {
	return &TranscriptionService{apiKeys: apiKeys, baseURLs: baseURLs}
}

func (t *TranscriptionService) Transcribe(ctx context.Context, userID, provider string, audioBytes []byte, filename string) (string, error) {
	if provider == "" {
		provider = "openai"
	}
	key, err := t.apiKeys.GetDecrypted(ctx, userID, provider)
	if err != nil {
		return "", err
	}
	client := openai.NewClientWithConfig(t.openAIConfig(provider, key))
	tmpFile, err := os.CreateTemp("", "luma-upload-*.m4a")
	if err != nil {
		return "", err
	}
	defer os.Remove(tmpFile.Name())
	if _, err := tmpFile.Write(audioBytes); err != nil {
		tmpFile.Close()
		return "", err
	}
	if err := tmpFile.Close(); err != nil {
		return "", err
	}
	resp, err := client.CreateTranscription(ctx, openai.AudioRequest{
		Model:    openai.Whisper1,
		FilePath: tmpFile.Name(),
	})
	if err != nil {
		return "", err
	}
	return resp.Text, nil
}

func (t *TranscriptionService) openAIConfig(provider string, apiKey string) openai.ClientConfig {
	cfg := openai.DefaultConfig(apiKey)
	if base := t.baseURLs[strings.ToLower(provider)]; base != "" {
		cfg.BaseURL = base
	}
	return cfg
}
