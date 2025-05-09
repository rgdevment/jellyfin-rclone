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
├── backup/                    # Backups del volumen de configuración de Jellyfin
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
- Usa tu propio `client_id` y `client_secret` de Google Cloud Console *(opcional pero recomendado)*
- Deja el resto como está o acepta los defaults
- Autentica en el navegador cuando lo pida

Después, puedes ver tu configuración guardada en `~/.config/rclone/rclone.conf`

Si necesitas tokens compartidos para un servidor sin navegador, también puedes copiar este archivo de otro equipo.

---

## 🚀 Clonar este repositorio

```bash
sudo git clone https://github.com/rgdevment/jellyfin-rclone.git /opt/jellyfin-rclone
cd /opt/jellyfin-rclone
```

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

## 💾 Backup de configuración de Jellyfin

En este proyecto, **el volumen `/config` apunta directamente a `/opt/backups/jellyfin`**, por lo tanto **la configuración de Jellyfin ya se guarda ahí directamente**.

No es necesario hacer ningún `cp` desde volúmenes Docker ni desde `/var/lib/docker/...`. Todo queda persistente en esa carpeta.

### ¿Qué incluye `/opt/backups/jellyfin`?

- Base de datos interna
- Lista de usuarios
- Configuraciones del servidor
- Colecciones
- Thumbnails y metadata descargada
- Plugins instalados manualmente

No incluye: archivos multimedia (porque están en Google Drive)

> ✅ Este enfoque facilita restauraciones, backups manuales y te permite ver/modificar configuraciones sin comandos especiales de Docker.

Para hacer un respaldo adicional externo (por ejemplo, a otro disco o nube):

```bash
tar czf jellyfin-backup.tar.gz -C /opt/backups jellyfin
```

Para restaurar:

```bash
mkdir -p /opt/backups/jellyfin
sudo tar xzf jellyfin-backup.tar.gz -C /opt/backups
```

---

## 🧹 Eliminar completamente Jellyfin y limpiar Docker

```bash
# Detener y eliminar contenedor Jellyfin
make down

# Eliminar contenedor (si existe)
docker rm -f jellyfin

# Eliminar imagen de Jellyfin
docker rmi jellyfin/jellyfin:latest

# Limpiar recursos huérfanos
docker volume prune -f
docker image prune -a -f
docker network prune -f
docker builder prune -f
```

> 🧠 Nota: Esto no borra tu respaldo en `/opt/backups/jellyfin`.

---

## 🆘 Nota importante para recuperación en caso de desastre

💡 Si pierdes el sistema y solo tienes el disco duro:

1. Accede al disco y **rescata la carpeta** `/opt/backups/jellyfin`
2. Guarda ese respaldo en un lugar seguro (otra máquina, nube, etc.)
3. Una vez reinstalado el sistema:
   - Instala Docker
   - Asegúrate de montar `/opt/backups/jellyfin` como volumen en `/config`
   - Clona el proyecto y levanta Jellyfin:

```bash
git clone https://github.com/tuusuario/jellyfin-rclone.git /opt/jellyfin-rclone
cd /opt/jellyfin-rclone
make up
```

✅ Todo volverá como estaba: usuarios, configuración, metadata y plugins. Y seguirás usando `/opt/backups/jellyfin` como tu volumen de datos persistente.

> ⚠️ rgdevment del futuro: **no copies nada desde `/var/lib/docker/...`**. Ya estás haciendo todo bien usando `/opt/backups/jellyfin`. Confía.

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
- La configuración persistente vive en `/opt/backups/jellyfin`
- Si cambias de servidor, solo necesitas montar esa ruta nuevamente

---

Hecho con ❤️ por el rgdevment del presente, para el rgdevment del futuro.
