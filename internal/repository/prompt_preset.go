package repository

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"

	"github.com/Juicern/luma/internal/domain"
)

type PromptPresetRepository struct {
	db *sql.DB
}

func NewPromptPresetRepository(db *sql.DB) *PromptPresetRepository {
	return &PromptPresetRepository{db: db}
}

func (r *PromptPresetRepository) List(ctx context.Context, userID string) ([]domain.PromptPreset, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, user_id, name, prompt_text, created_at, updated_at
		FROM user_prompt_presets
		WHERE user_id = ?
		ORDER BY created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var presets []domain.PromptPreset
	for rows.Next() {
		var preset domain.PromptPreset
		if err := rows.Scan(&preset.ID, &preset.UserID, &preset.Name, &preset.PromptText, &preset.CreatedAt, &preset.UpdatedAt); err != nil {
			return nil, err
		}
		presets = append(presets, preset)
	}

	return presets, rows.Err()
}

func (r *PromptPresetRepository) Get(ctx context.Context, id string) (domain.PromptPreset, error) {
	var preset domain.PromptPreset
	err := r.db.QueryRowContext(ctx, `
		SELECT id, user_id, name, prompt_text, created_at, updated_at
		FROM user_prompt_presets
		WHERE id = ?
	`, id).Scan(&preset.ID, &preset.UserID, &preset.Name, &preset.PromptText, &preset.CreatedAt, &preset.UpdatedAt)
	return preset, err
}

func (r *PromptPresetRepository) Create(ctx context.Context, userID, name, promptText string) (domain.PromptPreset, error) {
	now := time.Now().UTC()
	preset := domain.PromptPreset{
		ID:         uuid.NewString(),
		UserID:     userID,
		Name:       name,
		PromptText: promptText,
		CreatedAt:  now,
		UpdatedAt:  now,
	}

	_, err := r.db.ExecContext(ctx, `
		INSERT INTO user_prompt_presets (id, user_id, name, prompt_text, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?)
	`, preset.ID, preset.UserID, preset.Name, preset.PromptText, preset.CreatedAt, preset.UpdatedAt)
	return preset, err
}

func (r *PromptPresetRepository) Update(ctx context.Context, id, name, promptText string) (domain.PromptPreset, error) {
	now := time.Now().UTC()
	if _, err := r.db.ExecContext(ctx, `
		UPDATE user_prompt_presets
		SET name = ?, prompt_text = ?, updated_at = ?
		WHERE id = ?
	`, name, promptText, now, id); err != nil {
		return domain.PromptPreset{}, err
	}
	return r.Get(ctx, id)
}

func (r *PromptPresetRepository) Delete(ctx context.Context, id string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM user_prompt_presets WHERE id = ?`, id)
	return err
}
