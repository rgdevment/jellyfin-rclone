#!/bin/bash

# unmount-gdrive.sh - Desmonta el punto de montaje de Google Drive para Jellyfin

MOUNT_POINT="/mnt/gdrive"

if mount | grep -q "$MOUNT_POINT"; then
  echo "Desmontando $MOUNT_POINT..."
  sudo fusermount -u "$MOUNT_POINT" || sudo umount "$MOUNT_POINT"
  echo "✅ Desmontado correctamente."

  echo "Cerrando procesos rclone activos..."
  pkill -f "rclone mount gdrive:/media"

  echo "Limpiando cache temporal..."
  sudo rm -rf "$MOUNT_POINT/.cache"/*

  echo "✅ Limpieza finalizada."
else
  echo "ℹ️  $MOUNT_POINT no está montado."
fi
