package repository

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"

	"github.com/Juicern/luma/internal/domain"
)

type UserSessionRepository struct {
	db *sql.DB
}

func NewUserSessionRepository(db *sql.DB) *UserSessionRepository {
	return &UserSessionRepository{db: db}
}

func (r *UserSessionRepository) Create(ctx context.Context, userID, token string, expiresAt time.Time) (domain.UserSession, error) {
	session := domain.UserSession{
		ID:        uuid.NewString(),
		UserID:    userID,
		Token:     token,
		ExpiresAt: expiresAt,
		CreatedAt: time.Now().UTC(),
		LastUsed:  time.Now().UTC(),
	}
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO user_sessions (id, user_id, token, expires_at, created_at, last_used_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, session.ID, session.UserID, session.Token, session.ExpiresAt, session.CreatedAt, session.LastUsed)
	return session, err
}

func (r *UserSessionRepository) GetByToken(ctx context.Context, token string) (domain.UserSession, error) {
	var session domain.UserSession
	err := r.db.QueryRowContext(ctx, `
		SELECT id, user_id, token, expires_at, created_at, last_used_at
		FROM user_sessions
		WHERE token = $1
	`, token).Scan(&session.ID, &session.UserID, &session.Token, &session.ExpiresAt, &session.CreatedAt, &session.LastUsed)
	return session, err
}

func (r *UserSessionRepository) Touch(ctx context.Context, id string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE user_sessions
		SET last_used_at = $2
		WHERE id = $1
	`, id, time.Now().UTC())
	return err
}

func (r *UserSessionRepository) DeleteByToken(ctx context.Context, token string) error {
	_, err := r.db.ExecContext(ctx, `
		DELETE FROM user_sessions
		WHERE token = $1
	`, token)
	return err
}
