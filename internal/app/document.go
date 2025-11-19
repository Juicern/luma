package app

import (
	"errors"
	"fmt"
	"sync"
	"sync/atomic"
	"time"
)

var ErrDocumentNotFound = errors.New("document not found")

type Document struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

type DocumentService struct {
	logger Logger

	mu    sync.RWMutex
	seq   atomic.Int64
	items map[string]Document
}

func NewDocumentService(logger Logger) *DocumentService {
	return &DocumentService{
		logger: logger,
		items:  make(map[string]Document),
	}
}

func (s *DocumentService) List() []Document {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]Document, 0, len(s.items))
	for _, item := range s.items {
		result = append(result, item)
	}

	return result
}

func (s *DocumentService) Create(title, content string) Document {
	now := time.Now().UTC()
	id := s.nextID()

	doc := Document{
		ID:        id,
		Title:     title,
		Content:   content,
		CreatedAt: now,
		UpdatedAt: now,
	}

	s.mu.Lock()
	s.items[id] = doc
	s.mu.Unlock()

	s.logInfo("document created", "id", id)
	return doc
}

func (s *DocumentService) Get(id string) (Document, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	doc, ok := s.items[id]
	if !ok {
		return Document{}, ErrDocumentNotFound
	}

	return doc, nil
}

func (s *DocumentService) Update(id, title, content string) (Document, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	doc, ok := s.items[id]
	if !ok {
		return Document{}, ErrDocumentNotFound
	}

	doc.Title = title
	doc.Content = content
	doc.UpdatedAt = time.Now().UTC()

	s.items[id] = doc
	s.logInfo("document updated", "id", id)
	return doc, nil
}

func (s *DocumentService) Delete(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.items[id]; !ok {
		return ErrDocumentNotFound
	}

	delete(s.items, id)
	s.logInfo("document deleted", "id", id)
	return nil
}

func (s *DocumentService) nextID() string {
	id := s.seq.Add(1)
	return fmt.Sprintf("%s-%06d", time.Now().UTC().Format("20060102"), id)
}

func (s *DocumentService) logInfo(msg string, args ...any) {
	if s.logger != nil {
		s.logger.Info(msg, args...)
	}
}
