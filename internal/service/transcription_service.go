package service

import (
	"context"
	"fmt"
)

type TranscriptionService struct{}

func NewTranscriptionService() *TranscriptionService {
	return &TranscriptionService{}
}

func (t *TranscriptionService) Transcribe(_ context.Context, audioBytes []byte, filename string) (string, error) {
	return fmt.Sprintf("Transcribed %s (%d bytes)", filename, len(audioBytes)), nil
}
