package repository

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"

	"github.com/Juicern/luma/internal/domain"
)

type SessionRepository struct {
	db *sql.DB
}

func NewSessionRepository(db *sql.DB) *SessionRepository {
	return &SessionRepository{db: db}
}

func (r *SessionRepository) Create(ctx context.Context, session domain.Session) (domain.Session, error) {
	if session.ID == "" {
		session.ID = uuid.NewString()
	}
	now := time.Now().UTC()
	if session.CreatedAt.IsZero() {
		session.CreatedAt = now
	}
	session.UpdatedAt = now

	_, err := r.db.ExecContext(ctx, `
		INSERT INTO sessions (
			id, user_id, preset_id, provider_name, model, temporary_prompt, context_text,
			clipboard_enabled, system_prompt_id, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`, session.ID, session.UserID, session.PresetID, session.ProviderName, session.Model, session.TemporaryPrompt, session.ContextText,
		session.ClipboardEnabled, session.SystemPromptID, session.CreatedAt, session.UpdatedAt)

	return session, err
}

func (r *SessionRepository) UpdateContext(ctx context.Context, id string, temporaryPrompt, contextText *string, clipboard bool) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE sessions
		SET temporary_prompt = $1, context_text = $2, clipboard_enabled = $3, updated_at = CURRENT_TIMESTAMP
		WHERE id = $4
	`, temporaryPrompt, contextText, clipboard, id)
	return err
}

func (r *SessionRepository) List(ctx context.Context, userID string, limit int) ([]domain.Session, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, user_id, preset_id, provider_name, model, temporary_prompt, context_text, clipboard_enabled, system_prompt_id, created_at, updated_at
		FROM sessions
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sessions []domain.Session
	for rows.Next() {
		var session domain.Session
		if err := rows.Scan(&session.ID, &session.UserID, &session.PresetID, &session.ProviderName, &session.Model, &session.TemporaryPrompt, &session.ContextText,
			&session.ClipboardEnabled, &session.SystemPromptID, &session.CreatedAt, &session.UpdatedAt); err != nil {
			return nil, err
		}
		sessions = append(sessions, session)
	}
	return sessions, rows.Err()
}

func (r *SessionRepository) Get(ctx context.Context, id string) (domain.Session, error) {
	var session domain.Session
	err := r.db.QueryRowContext(ctx, `
		SELECT id, user_id, preset_id, provider_name, model, temporary_prompt, context_text, clipboard_enabled, system_prompt_id, created_at, updated_at
		FROM sessions
		WHERE id = $1
	`, id).Scan(&session.ID, &session.UserID, &session.PresetID, &session.ProviderName, &session.Model, &session.TemporaryPrompt, &session.ContextText,
		&session.ClipboardEnabled, &session.SystemPromptID, &session.CreatedAt, &session.UpdatedAt)
	return session, err
}
