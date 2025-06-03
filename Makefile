# Makefile para levantar Jellyfin y gestionar el servicio de montaje

.PHONY: up down restart

up:
	docker compose -f docker-compose.yml up -d --force-recreate rclone

# Apagar Jellyfin

down:
	docker compose -f docker-compose.yml down

# Reiniciar contenedor Jellyfin

restart:
	@echo "🔁 Reiniciando Jellyfin..."
	docker compose -f docker-compose.yml down
	sleep 2
	docker compose -f docker-compose.yml up -d --force-recreate rclone
