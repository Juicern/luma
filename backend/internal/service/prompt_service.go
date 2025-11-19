package service

import (
	"context"
	"database/sql"
	"errors"

	"github.com/Juicern/luma/internal/domain"
	"github.com/Juicern/luma/internal/repository"
)

const localUserID = "local-user"

type PromptService struct {
	systemRepo *repository.SystemPromptRepository
	presetRepo *repository.PromptPresetRepository
}

func NewPromptService(systemRepo *repository.SystemPromptRepository, presetRepo *repository.PromptPresetRepository) *PromptService {
	return &PromptService{
		systemRepo: systemRepo,
		presetRepo: presetRepo,
	}
}

func (s *PromptService) EnsureDefaultSystemPrompt(ctx context.Context) (domain.SystemPrompt, error) {
	prompt, err := s.systemRepo.GetActive(ctx)
	if err == nil {
		return prompt, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return domain.SystemPrompt{}, err
	}

	return s.systemRepo.Upsert(ctx, "Rewrite the provided transcript as a chat message: informal, concise, and conversational. Keep emotive markers and emojis if present; don't invent new ones. Lightly fix grammar, remove fillers/repetitions, and improve flow without changing meaning. Keep the original tone; only be professional if the transcript already is. Format any lists as proper bullet or numbered lists. Write numbers as numerals (e.g., 'five' → '5', 'twenty dollars' → '$20'). Format like a modern chat message with short lines, natural breaks, and emoji-friendly style. Do not add greetings, sign-offs, or commentary. Output only the rewritten chat message.")
}

func (s *PromptService) GetSystemPrompt(ctx context.Context) (domain.SystemPrompt, error) {
	prompt, err := s.systemRepo.GetActive(ctx)
	if err == nil {
		return prompt, nil
	}
	if errors.Is(err, sql.ErrNoRows) {
		return s.EnsureDefaultSystemPrompt(ctx)
	}
	return domain.SystemPrompt{}, err
}

func (s *PromptService) UpdateSystemPrompt(ctx context.Context, text string) (domain.SystemPrompt, error) {
	return s.systemRepo.Upsert(ctx, text)
}

func (s *PromptService) ListPresets(ctx context.Context) ([]domain.PromptPreset, error) {
	return s.presetRepo.List(ctx, localUserID)
}

func (s *PromptService) CreatePreset(ctx context.Context, name, text string) (domain.PromptPreset, error) {
	return s.presetRepo.Create(ctx, localUserID, name, text)
}

func (s *PromptService) UpdatePreset(ctx context.Context, id, name, text string) (domain.PromptPreset, error) {
	return s.presetRepo.Update(ctx, id, name, text)
}

func (s *PromptService) DeletePreset(ctx context.Context, id string) error {
	return s.presetRepo.Delete(ctx, id)
}

func (s *PromptService) GetPreset(ctx context.Context, id string) (domain.PromptPreset, error) {
	return s.presetRepo.Get(ctx, id)
}
