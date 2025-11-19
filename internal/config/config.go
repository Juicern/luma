package config

import (
	"os"
	"strconv"
	"time"
)

type Config struct {
	HTTPPort        string
	ShutdownTimeout time.Duration
}

func Load() Config {
	return Config{
		HTTPPort:        getEnv("HTTP_PORT", "8080"),
		ShutdownTimeout: getDuration("HTTP_SHUTDOWN_TIMEOUT", 10*time.Second),
	}
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getDuration(key string, fallback time.Duration) time.Duration {
	if value := os.Getenv(key); value != "" {
		if seconds, err := strconv.Atoi(value); err == nil {
			return time.Duration(seconds) * time.Second
		}
	}
	return fallback
}
