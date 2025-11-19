package config

import (
	"os"
	"strconv"
	"time"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Server    ServerConfig     `yaml:"server"`
	Database  DatabaseConfig   `yaml:"database"`
	Providers []ProviderConfig `yaml:"providers"`
	Security  SecurityConfig   `yaml:"security"`
}

type ServerConfig struct {
	Port            string        `yaml:"port"`
	ShutdownTimeout time.Duration `yaml:"-"`
}

type DatabaseConfig struct {
	DSN string `yaml:"dsn"`
}

type ProviderConfig struct {
	Name    string `yaml:"name"`
	BaseURL string `yaml:"base_url"`
}

type SecurityConfig struct {
	EncryptionKey    string `yaml:"encryption_key"`
	EncryptionKeyEnv string `yaml:"encryption_key_env"`
}

type fileConfig struct {
	Server struct {
		Port            string `yaml:"port"`
		ShutdownTimeout int    `yaml:"shutdown_timeout"`
	} `yaml:"server"`
	Database  DatabaseConfig   `yaml:"database"`
	Providers []ProviderConfig `yaml:"providers"`
	Security  SecurityConfig   `yaml:"security"`
}

func (f fileConfig) toConfig() Config {
	cfg := Config{
		Server: ServerConfig{
			Port: f.Server.Port,
		},
		Database:  f.Database,
		Providers: f.Providers,
		Security:  f.Security,
	}

	if f.Server.ShutdownTimeout > 0 {
		cfg.Server.ShutdownTimeout = time.Duration(f.Server.ShutdownTimeout) * time.Second
	}

	return cfg
}

func Load() Config {
	cfg := defaultConfig()

	if fileCfg, err := loadFromFile(); err == nil {
		cfg = mergeConfigs(cfg, fileCfg)
	}

	if port := os.Getenv("HTTP_PORT"); port != "" {
		cfg.Server.Port = port
	}

	if shutdown := os.Getenv("HTTP_SHUTDOWN_TIMEOUT"); shutdown != "" {
		if seconds, err := strconv.Atoi(shutdown); err == nil {
			cfg.Server.ShutdownTimeout = time.Duration(seconds) * time.Second
		}
	}

	if dsn := os.Getenv("LUMA_DB_DSN"); dsn != "" {
		cfg.Database.DSN = dsn
	}

	if key := os.Getenv(cfg.Security.EncryptionKeyEnv); key != "" {
		cfg.Security.EncryptionKey = key
	} else if key := os.Getenv("LUMA_SECRET_KEY"); key != "" {
		cfg.Security.EncryptionKey = key
	}

	return cfg
}

func defaultConfig() Config {
	return Config{
		Server: ServerConfig{
			Port:            "8080",
			ShutdownTimeout: 10 * time.Second,
		},
		Database: DatabaseConfig{
			DSN: "postgres://postgres:postgres@localhost:5432/luma?sslmode=disable",
		},
		Providers: []ProviderConfig{
			{Name: "openai", BaseURL: "https://api.openai.com/v1"},
			{Name: "gemini", BaseURL: "https://generativelanguage.googleapis.com/v1beta"},
		},
		Security: SecurityConfig{
			EncryptionKeyEnv: "LUMA_SECRET_KEY",
		},
	}
}

func loadFromFile() (Config, error) {
	path := os.Getenv("LUMA_CONFIG")
	if path == "" {
		path = "config.yaml"
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return Config{}, err
	}

	var cfg fileConfig
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return Config{}, err
	}

	return cfg.toConfig(), nil
}

func mergeConfigs(base, override Config) Config {
	if override.Server.Port != "" {
		base.Server.Port = override.Server.Port
	}
	if override.Server.ShutdownTimeout != 0 {
		base.Server.ShutdownTimeout = override.Server.ShutdownTimeout
	}
	if override.Database.DSN != "" {
		base.Database.DSN = override.Database.DSN
	}
	if len(override.Providers) > 0 {
		base.Providers = override.Providers
	}
	if override.Security.EncryptionKey != "" {
		base.Security.EncryptionKey = override.Security.EncryptionKey
	}
	if override.Security.EncryptionKeyEnv != "" {
		base.Security.EncryptionKeyEnv = override.Security.EncryptionKeyEnv
	}

	return base
}
