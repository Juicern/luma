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

func (r *APIKeyRepository) List(ctx context.Context) ([]domain.APIKey, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, provider_name, encrypted_key, created_at, updated_at
		FROM api_keys
		ORDER BY updated_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var keys []domain.APIKey
	for rows.Next() {
		var key domain.APIKey
		if err := rows.Scan(&key.ID, &key.ProviderName, &key.EncryptedKey, &key.CreatedAt, &key.UpdatedAt); err != nil {
			return nil, err
		}
		keys = append(keys, key)
	}
	return keys, rows.Err()
}

func (r *APIKeyRepository) Upsert(ctx context.Context, provider, encrypted string) (domain.APIKey, error) {
	now := time.Now().UTC()
	var existing domain.APIKey
	err := r.db.QueryRowContext(ctx, `
		SELECT id, provider_name, encrypted_key, created_at, updated_at
		FROM api_keys
		WHERE provider_name = ?
	`, provider).Scan(&existing.ID, &existing.ProviderName, &existing.EncryptedKey, &existing.CreatedAt, &existing.UpdatedAt)

	if err == sql.ErrNoRows {
		existing = domain.APIKey{
			ID:           uuid.NewString(),
			ProviderName: provider,
			EncryptedKey: encrypted,
			CreatedAt:    now,
			UpdatedAt:    now,
		}
		_, err := r.db.ExecContext(ctx, `
			INSERT INTO api_keys (id, provider_name, encrypted_key, created_at, updated_at)
			VALUES (?, ?, ?, ?, ?)
		`, existing.ID, existing.ProviderName, existing.EncryptedKey, existing.CreatedAt, existing.UpdatedAt)
		return existing, err
	}

	if err != nil {
		return domain.APIKey{}, err
	}

	existing.EncryptedKey = encrypted
	existing.UpdatedAt = now

	_, err = r.db.ExecContext(ctx, `
		UPDATE api_keys
		SET encrypted_key = ?, updated_at = ?
		WHERE id = ?
	`, existing.EncryptedKey, existing.UpdatedAt, existing.ID)
	return existing, err
}

func (r *APIKeyRepository) Delete(ctx context.Context, provider string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM api_keys WHERE provider_name = ?`, provider)
	return err
}

func (r *APIKeyRepository) GetByProvider(ctx context.Context, provider string) (domain.APIKey, error) {
	var key domain.APIKey
	err := r.db.QueryRowContext(ctx, `
		SELECT id, provider_name, encrypted_key, created_at, updated_at
		FROM api_keys
		WHERE provider_name = ?
	`, provider).Scan(&key.ID, &key.ProviderName, &key.EncryptedKey, &key.CreatedAt, &key.UpdatedAt)
	return key, err
}
