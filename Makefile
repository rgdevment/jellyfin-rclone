# Makefile para montar Google Drive y levantar Jellyfin

.PHONY: up down mount unmount status restart

up: mount
	sleep 3
	docker-compose -f docker-compose.yml up -d

down:
	docker-compose -f docker-compose.yml down

mount:
	@echo "🚀 Montando Google Drive..."
	./mount.sh

# No es necesario desmontar, no ocupa ram ni espacio montado, mejor dejarlo durmiendo.
unmount-sure:
	@echo "🔻 Desmontando Google Drive..."
	./unmount.sh

status:
	@echo "📦 Estado de montaje:"
	@mount | grep "/mnt/gdrive" || echo "❌ No montado"
	@echo "📺 Estado de Jellyfin:"
	@docker ps --filter name=jellyfin --format "Running: {{.Status}}" || echo "❌ Jellyfin no está corriendo"

restart:
	@echo "🔁 Reiniciando Jellyfin..."
	@if mount | grep -q "/mnt/gdrive"; then \
		echo "✅ GDrive ya está montado"; \
	else \
		echo "🔄 Montando GDrive antes de reiniciar..."; \
		./mount.sh; \
		sleep 3; \
	fi
	docker-compose -f docker-compose.yml down
	sleep 2
	docker-compose -f docker-compose.yml up -d
