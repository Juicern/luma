package service

import "errors"

var (
	ErrMissingAPIKey        = errors.New("missing API key for provider")
	ErrProviderNotSupported = errors.New("provider not supported")
)
