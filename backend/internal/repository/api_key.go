package repository

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"

	"github.com/Juicern/luma/internal/domain"
)

type APIKeyRepository struct {
	db *sql.DB
}

func NewAPIKeyRepository(db *sql.DB) *APIKeyRepository {
	return &APIKeyRepository{db: db}
}

func (r *APIKeyRepository) List(ctx context.Context, userID string) ([]domain.APIKey, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, user_id, provider_name, encrypted_key, created_at, updated_at
		FROM api_keys
		WHERE user_id = $1
		ORDER BY updated_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var keys []domain.APIKey
	for rows.Next() {
		var key domain.APIKey
		if err := rows.Scan(&key.ID, &key.UserID, &key.ProviderName, &key.EncryptedKey, &key.CreatedAt, &key.UpdatedAt); err != nil {
			return nil, err
		}
		keys = append(keys, key)
	}
	return keys, rows.Err()
}

func (r *APIKeyRepository) Upsert(ctx context.Context, userID, provider, encrypted string) (domain.APIKey, error) {
	now := time.Now().UTC()
	var existing domain.APIKey
	err := r.db.QueryRowContext(ctx, `
		SELECT id, user_id, provider_name, encrypted_key, created_at, updated_at
		FROM api_keys
		WHERE provider_name = $1 AND user_id = $2
	`, provider, userID).Scan(&existing.ID, &existing.UserID, &existing.ProviderName, &existing.EncryptedKey, &existing.CreatedAt, &existing.UpdatedAt)

	if err == sql.ErrNoRows {
		existing = domain.APIKey{
			ID:           uuid.NewString(),
			UserID:       userID,
			ProviderName: provider,
			EncryptedKey: encrypted,
			CreatedAt:    now,
			UpdatedAt:    now,
		}
		_, err := r.db.ExecContext(ctx, `
			INSERT INTO api_keys (id, user_id, provider_name, encrypted_key, created_at, updated_at)
			VALUES ($1, $2, $3, $4, $5, $6)
		`, existing.ID, existing.UserID, existing.ProviderName, existing.EncryptedKey, existing.CreatedAt, existing.UpdatedAt)
		return existing, err
	}

	if err != nil {
		return domain.APIKey{}, err
	}

	existing.EncryptedKey = encrypted
	existing.UpdatedAt = now

	_, err = r.db.ExecContext(ctx, `
		UPDATE api_keys
		SET encrypted_key = $1, updated_at = $2
		WHERE id = $3
	`, existing.EncryptedKey, existing.UpdatedAt, existing.ID)
	return existing, err
}

func (r *APIKeyRepository) Delete(ctx context.Context, userID, provider string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM api_keys WHERE provider_name = $1 AND user_id = $2`, provider, userID)
	return err
}

func (r *APIKeyRepository) GetByProvider(ctx context.Context, userID, provider string) (domain.APIKey, error) {
	var key domain.APIKey
	err := r.db.QueryRowContext(ctx, `
		SELECT id, user_id, provider_name, encrypted_key, created_at, updated_at
		FROM api_keys
		WHERE provider_name = $1 AND user_id = $2
	`, provider, userID).Scan(&key.ID, &key.UserID, &key.ProviderName, &key.EncryptedKey, &key.CreatedAt, &key.UpdatedAt)
	return key, err
}
