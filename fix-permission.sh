#!/bin/bash

CACHE_DIR="/opt/backups/jellyfin/transcode_cache"

if [ ! -d "$CACHE_DIR" ]; then
  echo "El directorio de caché no existe, creándolo..."
  mkdir -p "$CACHE_DIR"
fi

echo "Asegurando permisos para $CACHE_DIR..."
chmod 775 "$CACHE_DIR" # rwxrwxr-x
chown 1000:1000 "$CACHE_DIR" # Asegura que el propietario sea PUID/PGID

echo "Permisos de caché configurados."
