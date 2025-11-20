package domain

import "time"

type SystemPrompt struct {
	ID         string    `db:"id"`
	PromptText string    `db:"prompt_text"`
	Active     bool      `db:"active"`
	CreatedAt  time.Time `db:"created_at"`
	UpdatedAt  time.Time `db:"updated_at"`
}

type PromptPreset struct {
	ID          string    `db:"id" json:"id"`
	UserID      string    `db:"user_id" json:"user_id"`
	Name        string    `db:"name" json:"name"`
	PromptText  string    `db:"prompt_text" json:"prompt_text"`
	TemplateKey *string   `db:"template_key" json:"template_key,omitempty"`
	CreatedAt   time.Time `db:"created_at" json:"created_at"`
	UpdatedAt   time.Time `db:"updated_at" json:"updated_at"`
}

type APIKey struct {
	ID           string    `db:"id"`
	UserID       string    `db:"user_id"`
	ProviderName string    `db:"provider_name"`
	EncryptedKey string    `db:"encrypted_key"`
	CreatedAt    time.Time `db:"created_at"`
	UpdatedAt    time.Time `db:"updated_at"`
}

type Session struct {
	ID               string    `db:"id"`
	UserID           string    `db:"user_id"`
	PresetID         string    `db:"preset_id"`
	ProviderName     string    `db:"provider_name"`
	Model            string    `db:"model"`
	TemporaryPrompt  *string   `db:"temporary_prompt"`
	ContextText      *string   `db:"context_text"`
	SystemPromptID   string    `db:"system_prompt_id"`
	ClipboardEnabled bool      `db:"clipboard_enabled"`
	CreatedAt        time.Time `db:"created_at"`
	UpdatedAt        time.Time `db:"updated_at"`
}

type MessageType string

const (
	MessageTypeContent MessageType = "content"
	MessageTypeRewrite MessageType = "rewrite"
)

type Message struct {
	ID              string      `db:"id"`
	SessionID       string      `db:"session_id"`
	Type            MessageType `db:"type"`
	RawText         string      `db:"raw_text"`
	TransformedText *string     `db:"transformed_text"`
	CreatedAt       time.Time   `db:"created_at"`
}

type TranscriptionLog struct {
	ID              string    `db:"id"`
	UserID          string    `db:"user_id"`
	Mode            string    `db:"mode"`
	Transcript      string    `db:"transcript"`
	GeneratedText   *string   `db:"generated_text"`
	DurationSeconds float64   `db:"duration_seconds"`
	CreatedAt       time.Time `db:"created_at"`
}

type User struct {
	ID           string    `db:"id"`
	Name         string    `db:"name"`
	Email        string    `db:"email"`
	PasswordHash string    `db:"password_hash"`
	CreatedAt    time.Time `db:"created_at"`
}

type UserSession struct {
	ID        string    `db:"id"`
	UserID    string    `db:"user_id"`
	Token     string    `db:"token"`
	ExpiresAt time.Time `db:"expires_at"`
	CreatedAt time.Time `db:"created_at"`
	LastUsed  time.Time `db:"last_used_at"`
}
