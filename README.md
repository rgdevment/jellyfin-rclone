# 🍿 Jellyfin + Google Drive (rclone mount en Host con Systemd + Jellyfin en Docker) - Setup y Gestión

Este proyecto permite levantar un servidor Jellyfin que accede a tu biblioteca de medios almacenada en Google Drive. El montaje de `rclone` ahora se gestiona como un **servicio `systemd` directamente en el host Arch Linux**, ofreciendo robustez y eficiencia. Jellyfin se ejecuta en un contenedor Docker y accede a este montaje del host.

`rclone` debe estar previamente configurado en el sistema, ya que el servicio `systemd` utilizará esta configuración (por defecto, la del usuario que ejecuta el servicio).

---

## 🧱 Estructura General

    /opt/jellyfin-rclone/      # Directorio principal para scripts y Docker Compose de Jellyfin
    ├── docker-compose.yml     # Configuración de Docker Compose (solo Jellyfin)
    ├── Makefile               # Comandos útiles para iniciar/parar Jellyfin (adaptar)
    ├── cache/                 # Contiene subdirectorios para cachés
    │   ├── rclone/            # Caché VFS del rclone montado en host
    │   └── jellyfin/          # Caché de Jellyfin (mapeada desde Docker)
    ├── log/                   # Contiene logs
    │   ├── rclone-gdrive-mount.log # Log del montaje rclone del host
    │   └── jellyfin_logs/     # (Sugerencia) Logs de Jellyfin (mapeados desde Docker a su propio subdirectorio)
    └── legacy/                  # Scripts antiguos (referencia)

    /mnt/gdrive/                 # Punto de montaje en el HOST para Google Drive (usado por rclone systemd)
    /opt/backups/jellyfin/config # Configuración persistente de Jellyfin (mapeada desde Docker)
    /etc/systemd/system/rclone-gdrive.service # Archivo del servicio systemd para rclone

---

## 🧰 Configuración Inicial de Rclone en el Host

### 1. Instalar rclone (en Arch Linux)

Si aún no lo tienes:

    sudo pacman -S rclone

### 2. Configurar Google Drive con rclone

Este paso es crucial, ya que el servicio `systemd` usará esta configuración. Por defecto, si el servicio `systemd` corre como tu usuario `rgdevment`, usará `~/.config/rclone/rclone.conf`.

    rclone config

Sigue las instrucciones:

- `n` para nuevo remote.
- Nombre: `gdrive` (este es el nombre que usa el servicio `systemd` en el ejemplo).
- Almacenamiento: `drive` (busca el número correspondiente a Google Drive).
- Configura `client_id` y `client_secret` si los tienes (opcional pero recomendado para evitar límites de API de rclone genéricos).
- Scope: `1` (Full access all files).
- Deja `root_folder_id` y `service_account_file` en blanco (a menos que sepas lo que haces).
- Edit advanced config: `n` (No).
- Remote config: `y` (Sí, usar auto config).
- Autentica en el navegador cuando se abra.
- Configure this as a team drive: `n` (No, a menos que sea un Shared Drive).
- `y` (Yes this is OK).
- `q` (Quit config).

**Verifica tu archivo de configuración.** Si el servicio `systemd` corre como `rgdevment`, el archivo es `/home/rgdevment/.config/rclone/rclone.conf`. Asegúrate de que el usuario `rgdevment` pueda leerlo:

    sudo chmod 600 /home/rgdevment/.config/rclone/rclone.conf
    sudo chown rgdevment:rgdevment /home/rgdevment/.config/rclone/rclone.conf

**Nota Importante:** Es altamente recomendable especificar la ruta al archivo de configuración en el servicio `systemd` con la bandera `--config` en `ExecStart` para evitar cualquier ambigüedad, como se muestra en la sección de systemd.

### 3. Instalar y Configurar FUSE (en Arch Linux)

FUSE (Filesystem in Userspace) es necesario para que rclone pueda montar tu Google Drive.
sudo pacman -S fuse3

Asegúrate de que la opción `user_allow_other` esté descomentada en `/etc/fuse.conf`. Esto permite que los montajes FUSE iniciados por un usuario (incluso root o tu usuario `rgdevment`) sean accesibles por otros usuarios (como el usuario dentro del contenedor Jellyfin), lo cual es necesario si usas la opción `--allow-other` en rclone.

    sudo vim /etc/fuse.conf
    # Descomenta la línea: user_allow_other

Carga el módulo del kernel si es necesario (usualmente se carga automáticamente):
sudo modprobe fuse

---

## ⚙️ Configuración del Montaje Rclone en Host (Systemd)

1.  **Crear Directorios Necesarios en el Host (si no lo hiciste antes):**

    - Punto de montaje para rclone:

      sudo mkdir -p /mnt/gdrive
      sudo chown rgdevment:rgdevment /mnt/gdrive

    - Caché VFS de Rclone (host):

      sudo mkdir -p /opt/jellyfin-rclone/cache/rclone
      sudo chown -R rgdevment:rgdevment /opt/jellyfin-rclone/cache/rclone

    - Logs de Rclone (host):

      sudo mkdir -p /opt/jellyfin-rclone/log
      sudo chown -R rgdevment:rgdevment /opt/jellyfin-rclone/log

2.  **Crear el Archivo de Servicio `systemd`:**
    Crea el archivo `/etc/systemd/system/rclone-gdrive.service` (con `sudo vim`) con el siguiente contenido (este es el que finalizamos):

    [Unit]
    Description=Rclone Mount for Google Drive (gdrive:)
    Documentation=https://rclone.org/commands/rclone_mount/
    AssertPathIsDirectory=/mnt/gdrive
    After=network-online.target

    [Service]
    Type=simple
    User=rgdevment
    Group=rgdevment

    # ¡MUY RECOMENDADO! Añade la siguiente línea para ser explícito sobre qué rclone.conf usar:

    # Environment=RCLONE_CONFIG=/home/rgdevment/.config/rclone/rclone.conf

    # O, alternativamente, añade la bandera '--config /home/rgdevment/.config/rclone/rclone.conf'

    # directamente a la línea ExecStart. Sustituye la ruta si usas otra.

    ExecStart=/usr/bin/rclone mount gdrive: /mnt/gdrive \
     --allow-other \
     --dir-cache-time 1000h \
     --poll-interval 15s \
     --vfs-cache-mode full \
     --vfs-cache-max-size 12G \
     --vfs-cache-max-age 12h \
     --vfs-read-chunk-size 128M \
     --vfs-read-chunk-size-limit 2G \
     --buffer-size 512M \
     --drive-chunk-size 128M \
     --umask 002 \
     --cache-dir /opt/jellyfin-rclone/cache/rclone \
     --log-level INFO \
     --log-file /opt/jellyfin-rclone/log/rclone-gdrive-mount.log \
     --user-agent "Jellyfin Rclone Mount via Systemd"

    ExecStop=/usr/bin/fusermount3 -u /mnt/gdrive # Verifica esta ruta con 'which fusermount3'

    Restart=on-failure
    RestartSec=5s

    [Install]
    WantedBy=multi-user.target

3.  **Gestionar el Servicio `systemd`:**

    - Recargar `systemd` para que lea el nuevo archivo de servicio:

      sudo systemctl daemon-reload

    - Habilitar el servicio para que inicie automáticamente con el sistema:

      sudo systemctl enable rclone-gdrive.service

    - Iniciar el servicio ahora:

      sudo systemctl start rclone-gdrive.service

    - Verificar el estado del servicio:

      sudo systemctl status rclone-gdrive.service

      # Busca 'Active: active (running)'

    - Ver logs de rclone desde su archivo:

      tail -f /opt/jellyfin-rclone/log/rclone-gdrive-mount.log

    - Ver logs del servicio a través de journald:

      journalctl -u rclone-gdrive.service -f

    Asegúrate de que el montaje esté activo y accesible en el host:

    ls -l /mnt/gdrive
    df -h /mnt/gdrive
    mount | grep /mnt/gdrive

---

## 🚀 Despliegue de Jellyfin con Docker Compose

El archivo `/opt/jellyfin-rclone/docker-compose.yml` ahora solo se encarga de Jellyfin.

1.  **Preparar Directorios para Jellyfin (Docker) en el Host (si no lo hiciste antes):**

    - Configuración de Jellyfin:

      sudo mkdir -p /opt/backups/jellyfin/config
      sudo chown -R 1000:1000 /opt/backups/jellyfin/config # Usa PUID/PGID de Jellyfin

    - Caché de Jellyfin:

      sudo mkdir -p /opt/jellyfin-rclone/cache/jellyfin
      sudo chown -R 1000:1000 /opt/jellyfin-rclone/cache/jellyfin # Usa PUID/PGID de Jellyfin

    - Logs de Jellyfin (el directorio `/opt/jellyfin-rclone/log` ya debe existir y ser escribible por `rgdevment`. Si PUID 1000 es `rgdevment`, está bien. Si no, asegúrate de que PUID 1000 pueda escribir aquí o usa un grupo común).

2.  **Archivo `docker-compose.yml` (ubicado en `/opt/jellyfin-rclone/docker-compose.yml`):**
    Este es el que ya tienes y funciona:

    services:
    jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    read_only: true
    restart: unless-stopped
    tmpfs: - /tmp
    network_mode: bridge
    ports: - '8096:8096'
    volumes: - /opt/backups/jellyfin/config:/config - /opt/jellyfin-rclone/cache/jellyfin:/cache - /opt/jellyfin-rclone/log:/var/log/jellyfin # Logs de Jellyfin - /mnt/gdrive:/media/gdrive:ro # Montaje rclone del HOST
    environment: - TZ=America/Santiago - PUID=1000 - PGID=1000 - JELLYFIN_LOG_DIR=/var/log/jellyfin
    logging:
    driver: 'json-file'
    options:
    max-size: '10m'
    max-file: '3'

3.  **Iniciar Jellyfin:**
    Desde el directorio `/opt/jellyfin-rclone/` (o donde tengas tu `docker-compose.yml`):

        docker compose up -d jellyfin
        # o simplemente 'docker compose up -d' si Jellyfin es el único servicio.

4.  **Verificar Jellyfin:**

        docker compose ps
        docker compose logs -f jellyfin # Para ver los logs en vivo

    Accede a la interfaz web de Jellyfin (ej. `http://<tu_ip_del_host>:8096`) y configura tus bibliotecas de medios para que apunten a las carpetas dentro de `/media/gdrive` (por ejemplo, `/media/gdrive/Peliculas`, `/media/gdrive/Series`, etc.).

---

## 🚀 Comandos rápidos con Make (Adaptados)

Tu `Makefile` en `/opt/jellyfin-rclone/Makefile` puede adaptarse para reflejar la nueva estructura.

    # Makefile (Ejemplo Adaptado)
    .PHONY: up down restart status logs-jellyfin logs-rclone start-rclone stop-rclone status-rclone

    # Comandos para Jellyfin (Docker)
    up:
        docker compose up -d jellyfin

    down:
        docker compose down

    restart:
        docker compose restart jellyfin

    status:
        docker compose ps

    logs-jellyfin:
        docker compose logs -f jellyfin

    # Comandos para el servicio Rclone (Systemd)
    start-rclone:
        sudo systemctl start rclone-gdrive.service

    stop-rclone:
        sudo systemctl stop rclone-gdrive.service

    status-rclone:
        sudo systemctl status rclone-gdrive.service --no-pager

    logs-rclone:
        sudo tail -f /opt/jellyfin-rclone/log/rclone-gdrive-mount.log

---

## 💾 Backup de Configuración de Jellyfin

Esta sección sigue siendo válida: la configuración de Jellyfin se guarda directamente en `/opt/backups/jellyfin/config` en el host, gracias al mapeo de volumen en tu `docker-compose.yml`. Esto incluye la base de datos interna, usuarios, configuraciones del servidor, colecciones, metadata descargada, etc.

No incluye tus archivos multimedia, ya que estos residen en Google Drive y se acceden a través del montaje `rclone`.

**Para hacer un respaldo adicional externo de la configuración de Jellyfin** (por ejemplo, a otro disco o a la nube):

    tar czf jellyfin-config-backup_$(date +%Y%m%d).tar.gz -C /opt/backups/jellyfin config

(Esto crea un archivo llamado `jellyfin-config-backup_YYYYMMDD.tar.gz` que contiene la carpeta `config` y todo su contenido).

**Para restaurar tu configuración de Jellyfin desde un respaldo:**

1.  Asegúrate de que el contenedor Jellyfin esté detenido (`docker compose down`).
2.  Si es necesario, crea el directorio de destino (aunque `tar` usualmente no lo requiere si el directorio base `/opt/backups/jellyfin` existe):

        mkdir -p /opt/backups/jellyfin/config

3.  Extrae el contenido del backup en la ubicación correcta. Si tu backup `jellyfin-config-backup_FECHA.tar.gz` contiene la carpeta `config` en su raíz:

        # Navega al directorio donde está el archivo .tar.gz o especifica la ruta completa al archivo
        sudo tar xzf jellyfin-config-backup_FECHA.tar.gz -C /opt/backups/jellyfin

    Esto debería restaurar la carpeta `config` dentro de `/opt/backups/jellyfin/`.

4.  Asegúrate de que los permisos sean correctos para el PUID/PGID que usa Jellyfin (ej. 1000:1000):

        sudo chown -R 1000:1000 /opt/backups/jellyfin/config

5.  Vuelve a iniciar Jellyfin: `docker compose up -d jellyfin`.

---

## 🧹 Limpieza

Si necesitas desmantelar la configuración:

**Para Jellyfin (Docker):**

1.  Navega al directorio de tu `docker-compose.yml` (ej. `/opt/jellyfin-rclone/`).
2.  Detén y elimina los contenedores de Jellyfin definidos en el `docker-compose.yml`:

        docker compose down

3.  (Opcional) Elimina la imagen de Jellyfin para liberar espacio:

        docker rmi jellyfin/jellyfin:latest

4.  (Opcional) Considera una limpieza más profunda de Docker si quieres eliminar volúmenes anónimos no usados, redes, o la caché de construcción (usa con precaución):

        # docker system prune -a -f --volumes # ¡CUIDADO! Esto borra más cosas.
        docker volume prune -f                # Borra volúmenes no usados por ningún contenedor.
        docker network prune -f               # Borra redes no usadas.

**Para el montaje rclone del Host (servicio systemd):**

1.  Detén el servicio `rclone`:

        sudo systemctl stop rclone-gdrive.service

2.  (Opcional) Deshabilita el servicio para que no inicie en el boot:

        sudo systemctl disable rclone-gdrive.service

3.  (Opcional) Si quieres eliminar completamente la definición del servicio:

        sudo rm /etc/systemd/system/rclone-gdrive.service
        sudo systemctl daemon-reload # Para que systemd olvide el servicio eliminado

4.  (Opcional) Si quieres borrar los datos de caché de rclone, el log de rclone, y desmontar/eliminar el punto de montaje (¡ASEGÚRATE DE QUE YA NO LO NECESITAS!):

        # sudo umount /mnt/gdrive # systemctl stop debería haberlo hecho, pero por si acaso
        # sudo rm -rf /opt/jellyfin-rclone/cache/rclone
        # sudo rm -f /opt/jellyfin-rclone/log/rclone-gdrive-mount.log
        # sudo rmdir /mnt/gdrive # Solo si está vacío y no es un punto de montaje

**Importante:** La limpieza de los directorios de configuración de Jellyfin (`/opt/backups/jellyfin/config`) o los directorios de caché/log de rclone y Jellyfin en `/opt/jellyfin-rclone/` es manual y depende de si quieres conservar esos datos o no. Los comandos de Docker o systemd no borran estos volúmenes mapeados del host a menos que borres los directorios manualmente.

---

## 🆘 Nota importante para recuperación en caso de desastre

Si pierdes el sistema y solo tienes el disco duro:

1.  Accede al disco y **rescata las carpetas y archivos importantes**:
    - `/opt/backups/jellyfin/config` (Configuración de Jellyfin)
    - `/opt/jellyfin-rclone/` (Contiene las cachés de rclone y Jellyfin, y los logs)
    - `/home/rgdevment/.config/rclone/rclone.conf` (O la ruta que hayas especificado para la configuración de rclone que usa el servicio systemd)
    - (Opcional pero recomendado) Una copia de tu archivo `/etc/systemd/system/rclone-gdrive.service`.
2.  Guarda estos respaldos en un lugar seguro.
3.  Una vez reinstalado el sistema (Arch Linux):

    - Instala `rclone`, `fuse3`, Docker, y Docker Compose.
    - Restaura tu archivo `rclone.conf` a su ubicación (ej. `/home/rgdevment/.config/rclone/rclone.conf`).
    - Configura `user_allow_other` en `/etc/fuse.conf`.
    - Restaura el archivo `rclone-gdrive.service` a `/etc/systemd/system/`.
    - Restaura los directorios de datos/configuración/caché (`/mnt/gdrive`, `/opt/jellyfin-rclone/*`, `/opt/backups/jellyfin/config`) y asegúrate de que los permisos sean correctos para el usuario `rgdevment` (para rclone y sus directorios) y PUID/PGID 1000 (para los directorios de Jellyfin).
    - Ejecuta los siguientes comandos para el servicio rclone:

      sudo systemctl daemon-reload
      sudo systemctl enable --now rclone-gdrive.service

      # (--now hace enable y start al mismo tiempo)

    - Si tienes tu `docker-compose.yml` y `Makefile` en un repositorio git (como `/opt/jellyfin-rclone`):

      # git clone https://github.com/rgdevment/jellyfin-rclone.git /opt/jellyfin-rclone

      # cd /opt/jellyfin-rclone

      # make up # O docker compose up -d jellyfin

      (Ajusta si no usas git para estas partes, simplemente restaura el `docker-compose.yml` a `/opt/jellyfin-rclone/` y ejecuta `docker compose up -d jellyfin` desde ahí).

✅ Con esto, Jellyfin y el montaje de rclone deberían volver a funcionar como antes.

⚠️ rgdevment del futuro: **para los datos de Jellyfin, sigues usando los directorios mapeados del host, lo cual es bueno para la persistencia**. Para rclone, ahora es un servicio del host, lo que simplifica la interacción con Jellyfin en Docker.

---

## 🧠 Notas finales

- El montaje `rclone` de Google Drive es ahora un servicio robusto y persistente gestionado por `systemd` directamente en tu host Arch Linux.
- Jellyfin corre en un contenedor Docker y accede a este montaje del host de forma eficiente y en modo solo lectura.
- Las configuraciones cruciales (Jellyfin, rclone) y las cachés tienen rutas definidas y persistentes en el host, facilitando backups y la gestión.
- Este setup es más estable y fácil de depurar que intentar manejar montajes FUSE complejos desde dentro de Docker.

---

Hecho con ❤️ por el rgdevment del presente, para el rgdevment del futuro.
