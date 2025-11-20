package service

import (
	"context"
	"os"
	"strings"

	openai "github.com/sashabaranov/go-openai"

	"github.com/Juicern/luma/internal/domain"
	"github.com/Juicern/luma/internal/repository"
)

type TranscriptionService struct {
	apiKeys  *APIKeyService
	logs     *repository.TranscriptionLogRepository
	baseURLs map[string]string
}

func NewTranscriptionService(apiKeys *APIKeyService, logs *repository.TranscriptionLogRepository, baseURLs map[string]string) *TranscriptionService {
	return &TranscriptionService{
		apiKeys:  apiKeys,
		logs:     logs,
		baseURLs: baseURLs,
	}
}

func (t *TranscriptionService) Transcribe(ctx context.Context, userID, provider, mode string, duration float64, audioBytes []byte, filename string) (domain.TranscriptionLog, error) {
	if provider == "" {
		provider = "openai"
	}
	key, err := t.apiKeys.GetDecrypted(ctx, userID, provider)
	if err != nil {
		return domain.TranscriptionLog{}, err
	}
	client := openai.NewClientWithConfig(t.openAIConfig(provider, key))
	tmpFile, err := os.CreateTemp("", "luma-upload-*.m4a")
	if err != nil {
		return domain.TranscriptionLog{}, err
	}
	defer os.Remove(tmpFile.Name())
	if _, err := tmpFile.Write(audioBytes); err != nil {
		tmpFile.Close()
		return domain.TranscriptionLog{}, err
	}
	if err := tmpFile.Close(); err != nil {
		return domain.TranscriptionLog{}, err
	}
	resp, err := client.CreateTranscription(ctx, openai.AudioRequest{
		Model:    openai.Whisper1,
		FilePath: tmpFile.Name(),
	})
	if err != nil {
		return domain.TranscriptionLog{}, err
	}
	normalizedMode := normalizeMode(mode)
	entry, err := t.logs.Create(ctx, userID, normalizedMode, resp.Text, sanitizeDuration(duration), nil)
	if err != nil {
		return domain.TranscriptionLog{}, err
	}
	return entry, nil
}

func (t *TranscriptionService) AttachGeneratedText(ctx context.Context, logID, text string) error {
	return t.logs.UpdateGeneratedText(ctx, logID, text)
}

func (t *TranscriptionService) ListHistory(ctx context.Context, userID string, limit int) ([]domain.TranscriptionLog, error) {
	return t.logs.ListByUser(ctx, userID, limit)
}

func (t *TranscriptionService) Get(ctx context.Context, userID, id string) (domain.TranscriptionLog, error) {
	return t.logs.GetByID(ctx, userID, id)
}

func (t *TranscriptionService) openAIConfig(provider string, apiKey string) openai.ClientConfig {
	cfg := openai.DefaultConfig(apiKey)
	if base := t.baseURLs[strings.ToLower(provider)]; base != "" {
		cfg.BaseURL = base
	}
	return cfg
}

func normalizeMode(mode string) string {
	switch strings.ToLower(mode) {
	case "prompt", "temporary", "temporary_prompt":
		return "prompt"
	default:
		return "content"
	}
}

func sanitizeDuration(duration float64) float64 {
	if duration < 0 {
		return 0
	}
	return duration
}
