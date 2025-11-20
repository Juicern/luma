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
		SELECT id, user_id, name, prompt_text, template_key, created_at, updated_at
		FROM user_prompt_presets
		WHERE user_id = $1
		ORDER BY created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var presets []domain.PromptPreset
	for rows.Next() {
		preset, err := scanPromptPreset(rows)
		if err != nil {
			return nil, err
		}
		presets = append(presets, preset)
	}

	return presets, rows.Err()
}

func (r *PromptPresetRepository) Get(ctx context.Context, id string) (domain.PromptPreset, error) {
	return scanPromptPreset(r.db.QueryRowContext(ctx, `
		SELECT id, user_id, name, prompt_text, template_key, created_at, updated_at
		FROM user_prompt_presets
		WHERE id = $1
	`, id))
}

func (r *PromptPresetRepository) Create(ctx context.Context, userID, name, promptText string, templateKey *string) (domain.PromptPreset, error) {
	now := time.Now().UTC()
	id := uuid.NewString()
	if templateKey != nil {
		return scanPromptPreset(r.db.QueryRowContext(ctx, `
			INSERT INTO user_prompt_presets (id, user_id, name, prompt_text, template_key, created_at, updated_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			ON CONFLICT (user_id, template_key)
			DO UPDATE SET name = EXCLUDED.name,
			              prompt_text = EXCLUDED.prompt_text,
			              updated_at = EXCLUDED.updated_at
			RETURNING id, user_id, name, prompt_text, template_key, created_at, updated_at
		`, id, userID, name, promptText, templateKey, now, now))
	}

	return scanPromptPreset(r.db.QueryRowContext(ctx, `
		INSERT INTO user_prompt_presets (id, user_id, name, prompt_text, template_key, created_at, updated_at)
		VALUES ($1, $2, $3, $4, NULL, $5, $6)
		RETURNING id, user_id, name, prompt_text, template_key, created_at, updated_at
	`, id, userID, name, promptText, now, now))
}

func (r *PromptPresetRepository) Update(ctx context.Context, id, userID, name, promptText string, templateKey *string) (domain.PromptPreset, error) {
	now := time.Now().UTC()
	res, err := r.db.ExecContext(ctx, `
		UPDATE user_prompt_presets
		SET name = $1,
		    prompt_text = $2,
		    template_key = $3,
		    updated_at = $4
		WHERE id = $5 AND user_id = $6
	`, name, promptText, templateKey, now, id, userID)
	if err != nil {
		return domain.PromptPreset{}, err
	}
	if rows, _ := res.RowsAffected(); rows == 0 {
		return domain.PromptPreset{}, sql.ErrNoRows
	}
	return r.Get(ctx, id)
}

func (r *PromptPresetRepository) Delete(ctx context.Context, id, userID string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM user_prompt_presets WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return err
	}
	if rows, _ := res.RowsAffected(); rows == 0 {
		return sql.ErrNoRows
	}
	return nil
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanPromptPreset(row rowScanner) (domain.PromptPreset, error) {
	var preset domain.PromptPreset
	var tmpl sql.NullString
	err := row.Scan(&preset.ID, &preset.UserID, &preset.Name, &preset.PromptText, &tmpl, &preset.CreatedAt, &preset.UpdatedAt)
	if err != nil {
		return domain.PromptPreset{}, err
	}
	if tmpl.Valid {
		value := tmpl.String
		preset.TemplateKey = &value
	}
	return preset, nil
}
