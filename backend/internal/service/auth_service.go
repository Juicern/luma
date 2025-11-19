package service

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"

	"golang.org/x/crypto/bcrypt"

	"github.com/Juicern/luma/internal/domain"
	"github.com/Juicern/luma/internal/repository"
)

var (
	ErrInvalidCredentials = errors.New("invalid_credentials")
	ErrSessionExpired     = errors.New("session_expired")
	ErrSessionNotFound    = errors.New("session_not_found")
)

type AuthService struct {
	users    *repository.UserRepository
	sessions *repository.UserSessionRepository
}

func NewAuthService(users *repository.UserRepository, sessions *repository.UserSessionRepository) *AuthService {
	return &AuthService{users: users, sessions: sessions}
}

func (s *AuthService) Login(ctx context.Context, email, password string) (domain.User, domain.UserSession, error) {
	user, err := s.users.GetByEmail(ctx, email)
	if err != nil {
		return domain.User{}, domain.UserSession{}, ErrInvalidCredentials
	}
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)) != nil {
		return domain.User{}, domain.UserSession{}, ErrInvalidCredentials
	}
	token, err := generateToken()
	if err != nil {
		return domain.User{}, domain.UserSession{}, err
	}
	session, err := s.sessions.Create(ctx, user.ID, token, time.Now().Add(365*24*time.Hour))
	if err != nil {
		return domain.User{}, domain.UserSession{}, err
	}
	return user, session, nil
}

func (s *AuthService) Verify(ctx context.Context, token string) (domain.User, domain.UserSession, error) {
	session, err := s.sessions.GetByToken(ctx, token)
	if err != nil {
		return domain.User{}, domain.UserSession{}, ErrSessionNotFound
	}
	if session.ExpiresAt.Before(time.Now()) {
		_ = s.sessions.DeleteByToken(ctx, token)
		return domain.User{}, domain.UserSession{}, ErrSessionExpired
	}
	user, err := s.users.Get(ctx, session.UserID)
	if err != nil {
		return domain.User{}, domain.UserSession{}, err
	}
	_ = s.sessions.Touch(ctx, session.ID)
	return user, session, nil
}

func (s *AuthService) Logout(ctx context.Context, token string) error {
	return s.sessions.DeleteByToken(ctx, token)
}

func generateToken() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}
