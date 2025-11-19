package service

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"io"

	"github.com/Juicern/luma/internal/domain"
	"github.com/Juicern/luma/internal/repository"
)

type APIKeyService struct {
	repo *repository.APIKeyRepository
	key  []byte
}

func NewAPIKeyService(repo *repository.APIKeyRepository, encryptionKey string) *APIKeyService {
	hashed := sha256.Sum256([]byte(encryptionKey))
	return &APIKeyService{
		repo: repo,
		key:  hashed[:],
	}
}

func (s *APIKeyService) List(ctx context.Context, userID string) ([]domain.APIKey, error) {
	return s.repo.List(ctx, userID)
}

func (s *APIKeyService) Upsert(ctx context.Context, userID, provider, plaintext string) (domain.APIKey, error) {
	encrypted, err := s.encrypt(plaintext)
	if err != nil {
		return domain.APIKey{}, err
	}
	return s.repo.Upsert(ctx, userID, provider, encrypted)
}

func (s *APIKeyService) Delete(ctx context.Context, userID, provider string) error {
	return s.repo.Delete(ctx, userID, provider)
}

func (s *APIKeyService) GetDecrypted(ctx context.Context, userID, provider string) (string, error) {
	record, err := s.repo.GetByProvider(ctx, userID, provider)
	if err != nil {
		return "", err
	}
	return s.decrypt(record.EncryptedKey)
}

func (s *APIKeyService) encrypt(plaintext string) (string, error) {
	block, err := aes.NewCipher(s.key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}
	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

func (s *APIKeyService) decrypt(encoded string) (string, error) {
	data, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(s.key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	if len(data) < gcm.NonceSize() {
		return "", errors.New("ciphertext too short")
	}
	nonce, ciphertext := data[:gcm.NonceSize()], data[gcm.NonceSize():]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}
	return string(plaintext), nil
}
