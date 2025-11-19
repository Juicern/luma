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

	return s.systemRepo.Upsert(ctx, "You are Luma, a helpful writing assistant.")
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
