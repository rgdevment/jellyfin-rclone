# 🍿 Jellyfin + Google Drive (rclone mount) - Setup y Gestión

Este proyecto permite levantar un servidor Jellyfin que accede directamente a tu biblioteca de medios almacenada en Google Drive, usando `rclone mount` gestionado con `systemd`.

---

## 🧱 Estructura del Proyecto

```
/opt/jellyfin-rclone
├── docker-compose.yml         # Configuración de Jellyfin (con restart: unless-stopped)
├── Makefile                   # Comandos útiles para iniciar/parar servicios
├── rclone-mount.service       # Servicio systemd que monta Google Drive en /mnt/gdrive
├── legacy/mount.sh            # Script antiguo de montaje (referencia únicamente)
├── legacy/unmount.sh          # Script antiguo de desmontaje manual (ahora gestionado por systemd)
├── cache/                     # Caché de VFS de rclone
├── log/                       # Logs del montaje rclone
└── /mnt/gdrive                # Punto de montaje de medios (Google Drive)
```

---

## 🧰 Instalación inicial de rclone y configuración de Google Drive

### 1. Instalar rclone

```bash
curl https://rclone.org/install.sh | sudo bash
```

### 2. Configurar Google Drive con rclone

```bash
rclone config
```

Selecciona:

- `n` para crear un nuevo remote
- Nombre sugerido: `gdrive`
- Tipo de almacenamiento: `drive`
- Usa tu propio `client_id` y `client_secret` de Google Cloud Console _(opcional pero recomendado)_
- Deja el resto como está o acepta los defaults
- Autentica en el navegador cuando lo pida

Después, puedes ver tu configuración guardada en `~/.config/rclone/rclone.conf`

Si necesitas tokens compartidos para un servidor sin navegador, también puedes copiar este archivo de otro equipo.

---

## 🚀 Comandos rápidos con Make

```bash
make up                    # Levanta Jellyfin (requiere que el montaje ya esté activo)
make down                  # Detiene Jellyfin
make restart               # Reinicia Jellyfin
make status                # Muestra estado del contenedor y del montaje

make mount-service-start   # Inicia el servicio de montaje
make mount-service-status  # Muestra estado del servicio
make mount-service-logs    # Muestra últimos 50 logs del montaje
make mount-service-restart # Reinicia el servicio de montaje
make mount-service-stop    # Detiene el montaje
```

---

## 🛠️ Crear el servicio `rclone-mount` (una vez)

1. Crea el archivo:

   ```bash
   sudo vim /etc/systemd/system/rclone-mount.service
   ```

2. Pega este contenido:

   ```ini
   [Unit]
   Description=Montar Google Drive en /mnt/gdrive con rclone (para Jellyfin)
   After=network-online.target
   Wants=network-online.target

   [Service]
   Type=simple
   User=rgdevment
   ExecStartPre=/usr/bin/mkdir -p /mnt/gdrive
   ExecStartPre=/usr/bin/chown rgdevment:rgdevment /mnt/gdrive
   ExecStart=/usr/bin/rclone mount gdrive:/Media /mnt/gdrive \
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
     --log-file=/opt/jellyfin-rclone/log/rclone-media.log
   ExecStop=/bin/fusermount -u /mnt/gdrive
   Restart=on-failure
   RestartSec=10

   [Install]
   WantedBy=multi-user.target
   ```

3. Activa y habilita el servicio:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable rclone-mount
   sudo systemctl start rclone-mount
   ```

---

## 🧼 Cómo eliminar o desactivar el servicio

```bash
sudo systemctl stop rclone-mount
sudo systemctl disable rclone-mount
sudo rm /etc/systemd/system/rclone-mount.service
sudo systemctl daemon-reload
```

---

## 👁️ Verificar el montaje

```bash
mount | grep gdrive
findmnt /mnt/gdrive
journalctl -u rclone-mount -f
```

---

## 🧠 Notas finales

- Los scripts en `legacy/` (`mount.sh`, `unmount.sh`) se mantienen solo como referencia manual
- Jellyfin inicia automáticamente vía Docker si usas `restart: unless-stopped`
- El montaje rclone es ahora persistente y supervisado por systemd

---

Hecho con ❤️ por el rgdevment del presente, para el rgdevment del futuro.
