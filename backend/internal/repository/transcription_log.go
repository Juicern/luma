package repository

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"

	"github.com/Juicern/luma/internal/domain"
)

type TranscriptionLogRepository struct {
	db *sql.DB
}

func NewTranscriptionLogRepository(db *sql.DB) *TranscriptionLogRepository {
	return &TranscriptionLogRepository{db: db}
}

func (r *TranscriptionLogRepository) Create(ctx context.Context, userID, mode, transcript string, duration float64, generatedText *string) (domain.TranscriptionLog, error) {
	now := time.Now().UTC()
	entry := domain.TranscriptionLog{
		ID:              uuid.NewString(),
		UserID:          userID,
		Mode:            mode,
		Transcript:      transcript,
		GeneratedText:   generatedText,
		DurationSeconds: duration,
		CreatedAt:       now,
	}

	_, err := r.db.ExecContext(ctx, `
		INSERT INTO transcription_logs (id, user_id, mode, transcript, generated_text, duration_seconds, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, entry.ID, entry.UserID, entry.Mode, entry.Transcript, entry.GeneratedText, entry.DurationSeconds, entry.CreatedAt)
	return entry, err
}

func (r *TranscriptionLogRepository) UpdateGeneratedText(ctx context.Context, id string, text string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE transcription_logs
		SET generated_text = $1
		WHERE id = $2
	`, text, id)
	return err
}

func (r *TranscriptionLogRepository) GetByID(ctx context.Context, userID, id string) (domain.TranscriptionLog, error) {
	var entry domain.TranscriptionLog
	var generated sql.NullString
	err := r.db.QueryRowContext(ctx, `
		SELECT id, user_id, mode, transcript, generated_text, duration_seconds, created_at
		FROM transcription_logs
		WHERE id = $1 AND user_id = $2
	`, id, userID).Scan(&entry.ID, &entry.UserID, &entry.Mode, &entry.Transcript, &generated, &entry.DurationSeconds, &entry.CreatedAt)
	if err != nil {
		return domain.TranscriptionLog{}, err
	}
	if generated.Valid {
		value := generated.String
		entry.GeneratedText = &value
	}
	return entry, nil
}

func (r *TranscriptionLogRepository) ListByUser(ctx context.Context, userID string, limit int) ([]domain.TranscriptionLog, error) {
	if limit <= 0 {
		limit = 50
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, user_id, mode, transcript, generated_text, duration_seconds, created_at
		FROM transcription_logs
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []domain.TranscriptionLog
	for rows.Next() {
		var entry domain.TranscriptionLog
		var generated sql.NullString
		if err := rows.Scan(&entry.ID, &entry.UserID, &entry.Mode, &entry.Transcript, &generated, &entry.DurationSeconds, &entry.CreatedAt); err != nil {
			return nil, err
		}
		if generated.Valid {
			value := generated.String
			entry.GeneratedText = &value
		}
		logs = append(logs, entry)
	}
	return logs, rows.Err()
}
