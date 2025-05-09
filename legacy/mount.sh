#!/bin/bash

# DEPRECATED: Este script ya no se usa porque el montaje lo hace systemd vía rclone-mount.service
# Se conserva solo como referencia manual.

#🔧 El montaje de Google Drive ahora es manejado por systemd:
#  - Servicio: rclone-mount.service
#  - Requiere FUSE, permisos de sudo configurados
#  - Ver logs con: journalctl -u rclone-mount -f

# mount-gdrive.sh - Monta Google Drive en /mnt/gdrive para uso con Jellyfin

# Asegúrate de tener FUSE activado con user_allow_other en /etc/fuse.conf
# Crea el punto de montaje si no existe
sudo mkdir -p /mnt/gdrive
sudo chown "$USER":"$USER" /mnt/gdrive

if mountpoint -q /mnt/gdrive; then
  echo "ℹ️  /mnt/gdrive ya está montado. No se realizará el montaje de nuevo."
  exit 0
fi

if ! mountpoint -q /mnt/gdrive; then
  echo "🧹 Limpiando /mnt/gdrive antes del montaje..."
  sudo find /mnt/gdrive -mindepth 1 -delete
fi

# Monta Google Drive:/media en /mnt/gdrive con cache VFS
rclone mount gdrive:/Media /mnt/gdrive \
  --vfs-cache-mode=full \
  --vfs-cache-max-size=12G \
  --vfs-cache-max-age=12h \
  --allow-other \
  --dir-cache-time=1000h \
  --poll-interval=15s \
  --buffer-size=512M \
  --drive-chunk-size=128M \
  --vfs-read-chunk-size=128M \
  --vfs-read-chunk-size-limit=2G \
  --umask 002 \
  --cache-dir=/opt/jellyfin-rclone/cache \
  --log-level INFO \
  --log-file=/opt/jellyfin-rclone/log/rclone-media.log &

# Esperar hasta 30 segundos que el montaje se active
echo "⏳ Esperando que /mnt/gdrive esté montado..."
tries=0
max_tries=15

until mountpoint -q /mnt/gdrive; do
  sleep 2
  tries=$((tries+1))
  if [ "$tries" -ge "$max_tries" ]; then
    echo "❌ Error: No se pudo montar /mnt/gdrive después de $((max_tries*2)) segundos."
    exit 1
  fi
done

# Mostrar confirmación
echo "✅ Google Drive montado en /mnt/gdrive con VFS cache activo (12G / 12h)."
echo "Puedes usar este volumen en Jellyfin como /media/gdrive."
echo "Para desmontar: sudo fusermount -u /mnt/gdrive"
