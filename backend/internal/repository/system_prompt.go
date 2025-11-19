package repository

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/Juicern/luma/internal/domain"
)

type SystemPromptRepository struct {
	db *sql.DB
}

func NewSystemPromptRepository(db *sql.DB) *SystemPromptRepository {
	return &SystemPromptRepository{db: db}
}

func (r *SystemPromptRepository) GetActive(ctx context.Context) (domain.SystemPrompt, error) {
	var prompt domain.SystemPrompt
	err := r.db.QueryRowContext(ctx, `
		SELECT id, prompt_text, active, created_at, updated_at
		FROM system_prompts
		WHERE active = TRUE
		ORDER BY updated_at DESC
		LIMIT 1
	`).Scan(&prompt.ID, &prompt.PromptText, &prompt.Active, &prompt.CreatedAt, &prompt.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return domain.SystemPrompt{}, sql.ErrNoRows
		}
		return domain.SystemPrompt{}, err
	}
	return prompt, nil
}

func (r *SystemPromptRepository) Upsert(ctx context.Context, promptText string) (domain.SystemPrompt, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return domain.SystemPrompt{}, err
	}
	defer tx.Rollback()

	var prompt domain.SystemPrompt
	err = tx.QueryRowContext(ctx, `SELECT id, prompt_text, active, created_at, updated_at FROM system_prompts WHERE active = TRUE LIMIT 1`).
		Scan(&prompt.ID, &prompt.PromptText, &prompt.Active, &prompt.CreatedAt, &prompt.UpdatedAt)
	now := time.Now().UTC()
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			prompt = domain.SystemPrompt{
				ID:         uuid.NewString(),
				PromptText: promptText,
				Active:     true,
				CreatedAt:  now,
				UpdatedAt:  now,
			}
			if _, err := tx.ExecContext(ctx, `
				INSERT INTO system_prompts (id, prompt_text, active, created_at, updated_at)
				VALUES ($1, $2, TRUE, $3, $4)
			`, prompt.ID, prompt.PromptText, prompt.CreatedAt, prompt.UpdatedAt); err != nil {
				return domain.SystemPrompt{}, err
			}
		} else {
			return domain.SystemPrompt{}, err
		}
	} else {
		prompt.PromptText = promptText
		prompt.UpdatedAt = now
		if _, err := tx.ExecContext(ctx, `
			UPDATE system_prompts
			SET prompt_text = $1, updated_at = $2
			WHERE id = $3
		`, prompt.PromptText, prompt.UpdatedAt, prompt.ID); err != nil {
			return domain.SystemPrompt{}, err
		}
	}

	if err := tx.Commit(); err != nil {
		return domain.SystemPrompt{}, err
	}

	return prompt, nil
}
