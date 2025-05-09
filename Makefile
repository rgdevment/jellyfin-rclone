# Makefile para levantar Jellyfin y gestionar el servicio de montaje

.PHONY: up down status restart \
        mount-service-start mount-service-status mount-service-logs mount-service-restart mount-service-stop

up:
	docker compose -f docker-compose.yml up -d

# Apagar Jellyfin

down:
	docker compose -f docker-compose.yml down

# Estado de servicios y montaje

status:
	@echo "📦 Estado de montaje (rclone):"
	@mount | grep "/mnt/gdrive" || echo "❌ No montado"
	@echo "📺 Estado de Jellyfin (docker):"
	@docker ps --filter name=jellyfin --format "Running: {{.Status}}" || echo "❌ Jellyfin no está corriendo"

# Reiniciar contenedor Jellyfin

restart:
	@echo "🔁 Reiniciando Jellyfin..."
	docker compose -f docker-compose.yml down
	sleep 2
	docker compose -f docker-compose.yml up -d

# Gestión del servicio systemd de montaje

mount-service-start:
	sudo systemctl start rclone-mount

mount-service-status:
	systemctl status rclone-mount

mount-service-logs:
	journalctl -u rclone-mount -n 50 --no-pager

mount-service-restart:
	sudo systemctl restart rclone-mount

mount-service-stop:
	sudo systemctl stop rclone-mount
