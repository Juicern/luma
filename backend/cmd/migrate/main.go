package main

import (
	"context"
	"log"

	"github.com/Juicern/luma/internal/config"
	"github.com/Juicern/luma/internal/storage"
)

func main() {
	cfg := config.Load()

	ctx := context.Background()

	db, err := storage.NewDatabase(ctx, cfg.Database)
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	defer db.Close()

	if err := storage.RunMigrations(ctx, db); err != nil {
		log.Fatalf("migrate: %v", err)
	}

	log.Println("Migrations applied successfully.")
}
