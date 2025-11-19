package service

import (
	"context"

	"golang.org/x/crypto/bcrypt"

	"github.com/Juicern/luma/internal/domain"
	"github.com/Juicern/luma/internal/repository"
)

type UserService struct {
	repo *repository.UserRepository
}

func NewUserService(repo *repository.UserRepository) *UserService {
	return &UserService{repo: repo}
}

func (s *UserService) Create(ctx context.Context, name, email, password string) (domain.User, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return domain.User{}, err
	}
	return s.repo.Create(ctx, name, email, string(hash))
}

func (s *UserService) List(ctx context.Context) ([]domain.User, error) {
	return s.repo.List(ctx)
}

func (s *UserService) Get(ctx context.Context, id string) (domain.User, error) {
	return s.repo.Get(ctx, id)
}
