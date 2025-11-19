package repository

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"

	"github.com/Juicern/luma/internal/domain"
)

type MessageRepository struct {
	db *sql.DB
}

func NewMessageRepository(db *sql.DB) *MessageRepository {
	return &MessageRepository{db: db}
}

func (r *MessageRepository) Create(ctx context.Context, msg domain.Message) (domain.Message, error) {
	if msg.ID == "" {
		msg.ID = uuid.NewString()
	}
	if msg.CreatedAt.IsZero() {
		msg.CreatedAt = time.Now().UTC()
	}

	_, err := r.db.ExecContext(ctx, `
		INSERT INTO messages (id, session_id, type, raw_text, transformed_text, created_at)
		VALUES (?, ?, ?, ?, ?, ?)
	`, msg.ID, msg.SessionID, msg.Type, msg.RawText, msg.TransformedText, msg.CreatedAt)
	return msg, err
}

func (r *MessageRepository) UpdateTransformedText(ctx context.Context, id string, transformed string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE messages
		SET transformed_text = ?
		WHERE id = ?
	`, transformed, id)
	return err
}

func (r *MessageRepository) Get(ctx context.Context, id string) (domain.Message, error) {
	var msg domain.Message
	err := r.db.QueryRowContext(ctx, `
		SELECT id, session_id, type, raw_text, transformed_text, created_at
		FROM messages
		WHERE id = ?
	`, id).Scan(&msg.ID, &msg.SessionID, &msg.Type, &msg.RawText, &msg.TransformedText, &msg.CreatedAt)
	return msg, err
}

func (r *MessageRepository) ListBySession(ctx context.Context, sessionID string) ([]domain.Message, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, session_id, type, raw_text, transformed_text, created_at
		FROM messages
		WHERE session_id = ?
		ORDER BY created_at ASC
	`, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []domain.Message
	for rows.Next() {
		var msg domain.Message
		if err := rows.Scan(&msg.ID, &msg.SessionID, &msg.Type, &msg.RawText, &msg.TransformedText, &msg.CreatedAt); err != nil {
			return nil, err
		}
		messages = append(messages, msg)
	}
	return messages, rows.Err()
}
