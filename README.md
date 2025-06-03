# 🍿 Jellyfin + Google Drive (rclone mount con Docker Compose) - Setup y Gestión

Este proyecto permite levantar un servidor Jellyfin que accede directamente a tu biblioteca de medios almacenada en Google Drive. Ahora, el montaje de `rclone` se gestiona como un **servicio de Docker Compose** dentro de un contenedor, asegurando un inicio coordinado con Jellyfin. `rclone` debe estar previamente configurado en el sistema para poder acceder a tu `rclone.conf` y para tus necesidades de backups y otras tareas.

---

## 🧱 Estructura del Proyecto

    /opt/jellyfin-rclone
    ├── docker-compose.yml         # Configuración de Jellyfin y rclone mount (con restart: unless-stopped)
    ├── Makefile                   # Comandos útiles para iniciar/parar servicios
    ├── legacy/mount.sh            # Script antiguo de montaje (referencia únicamente)
    ├── legacy/unmount.sh          # Script antiguo de desmontaje manual (ahora gestionado por Docker Compose)
    ├── cache/                     # Caché de VFS de rclone (Ahora gestionada a través de Docker Compose)
    ├── log/                       # Logs del montaje rclone (Ahora gestionada a través de Docker Compose)
    ├── backup/                    # Backups del volumen de configuración de Jellyfin (ver detalles en Backup)
    └── /mnt/gdrive                # Punto de montaje de medios (Google Drive)

---

## 🧰 Instalación inicial de rclone y configuración de Google Drive

### 1. Instalar rclone (en el sistema)

`rclone` debe estar instalado en tu sistema. Esto es necesario para la configuración inicial de tus remotes y para cualquier tarea de backup o gestión de archivos que realices directamente en el host. El contenedor de `rclone` utilizará la configuración generada aquí.

    sudo apt update && sudo apt install unzip -y
    curl https://rclone.org/install.sh | sudo bash

### 2. Configurar Google Drive con rclone (en el sistema)

    rclone config

Selecciona:

- `n` para crear un nuevo remote
- Nombre sugerido: `gdrive` (es crucial usar este nombre para la configuración en `docker-compose.yml`)
- Tipo de almacenamiento: `drive`
- Usa tu propio `client_id` y `client_secret` de Google Cloud Console _(opcional pero recomendado)_
- Deja el resto como está o acepta los defaults
- Autentica en el navegador cuando lo pida

Después, puedes ver tu configuración guardada en `~/.config/rclone/rclone.conf`. **Este archivo será utilizado por el contenedor de `rclone` para realizar el montaje.**

Si necesitas tokens compartidos para un servidor sin navegador, también puedes copiar este archivo de otro equipo.

---

## 🚀 Clonar este repositorio y Preparar el entorno

    sudo git clone https://github.com/rgdevment/jellyfin-rclone.git /opt/jellyfin-rclone
    cd /opt/jellyfin-rclone

### **1. Asegurar permisos de archivos de configuración en el host**

Para asegurar el correcto acceso al archivo de configuración de rclone:

    sudo chmod 600 /home/rgdevment/.config/rclone/rclone.conf

---

## 🚀 Comandos rápidos con Make

    make up                    # Levanta Jellyfin Y el montaje de rclone
    make down                  # Detiene Jellyfin y el montaje de rclone
    make restart               # Reinicia Jellyfin
    make status                # Muestra estado de los contenedores (ajustar Makefile para mostrar ambos)

    # Los comandos 'make mount-service-*' ya no son necesarios, el montaje se gestiona con 'docker-compose'.

---

## 🚀 Despliegue con Docker Compose

El archivo `docker-compose.yml` ahora contiene la definición de los servicios de Jellyfin y rclone, incluyendo sus dependencias para un inicio coordinado.

### **1. Iniciar Docker Compose**

Desde el directorio `/opt/jellyfin-rclone/`:

    docker-compose up -d --force-recreate rclone jellyfin

### **2. Verificar el estado de los servicios**

    docker-compose ps
    docker-compose logs rclone
    docker-compose logs jellyfin

Asegúrate de que ambos servicios estén en estado `running` y `healthy`.

---

## 💾 Backup de configuración de Jellyfin

En este proyecto, **el volumen `/config` de Jellyfin apunta directamente a `/opt/backups/jellyfin/config`**, por lo tanto **la configuración de Jellyfin ya se guarda ahí directamente**.

No es necesario hacer ningún `cp` desde volúmenes Docker ni desde `/var/lib/docker/...`. Todo queda persistente en esa carpeta.

### ¿Qué incluye `/opt/backups/jellyfin/config`?

- Base de datos interna
- Lista de usuarios
- Configuraciones del servidor
- Colecciones
- Thumbnails y metadata descargada
- Plugins instalados manualmente

No incluye: archivos multimedia (porque están en Google Drive)

✅ Este enfoque facilita restauraciones, backups manuales y te permite ver/modificar configuraciones sin comandos especiales de Docker.

Para hacer un respaldo adicional externo (por ejemplo, a otro disco o nube):

    tar czf jellyfin-backup.tar.gz -C /opt/backups/jellyfin config

Para restaurar:

    mkdir -p /opt/backups/jellyfin/config
    sudo tar xzf jellyfin-backup.tar.gz -C /opt/backups/jellyfin

---

## 🧹 Eliminar completamente Jellyfin y limpiar Docker

    # Detener y eliminar los servicios Docker Compose
    docker-compose down

    # Eliminar imagen de Jellyfin (opcional)
    docker rmi jellyfin/jellyfin:latest

    # Eliminar imagen de rclone (opcional)
    docker rmi rclone/rclone:latest

    # Limpiar recursos huérfanos de Docker (volúmenes anónimos, redes no utilizadas)
    docker volume prune -f
    docker image prune -a -f
    docker network prune -f
    docker builder prune -f

🧠 Nota: Esto no borra tus respaldos en `/opt/backups/jellyfin` ni `/opt/jellyfin-rclone`.

---

## 🆘 Nota importante para recuperación en caso de desastre

💡 Si pierdes el sistema y solo tienes el disco duro:

1.  Accede al disco y **rescata las carpetas**:
    - `/opt/backups/jellyfin`
    - `/opt/jellyfin-rclone`
    - `/home/rgdevment/.config/rclone`
2.  Guarda esos respaldos en un lugar seguro (otra máquina, nube, etc.)
3.  Una vez reinstalado el sistema:

    - Instala Docker y Docker Compose
    - Restablece las carpetas de respaldo en sus ubicaciones originales (`/opt/backups/jellyfin`, `/opt/jellyfin-rclone`, `/home/rgdevment/.config/rclone`)
    - Asegúrate de configurar `fuse` (`user_allow_other`).
    - Clona este repositorio y levanta Jellyfin:

      git clone https://github.com/rgdevment/jellyfin-rclone.git /opt/jellyfin-rclone
      cd /opt/jellyfin-rclone
      docker-compose up -d

✅ Todo volverá como estaba: usuarios, configuración, metadata y plugins. Y seguirás usando tus volúmenes persistentes.

⚠️ rgdevment del futuro: **no copies nada desde `/var/lib/docker/...`**. Ya estás haciendo todo bien usando los directorios mapeados en el host. Confía.

---

## 🧠 Notas finales

- Los scripts en `legacy/` (`mount.sh`, `unmount.sh`) se mantienen solo como referencia manual
- Jellyfin inicia automáticamente vía Docker Compose si usas `restart: unless-stopped`
- El montaje rclone es ahora persistente y supervisado por Docker Compose
- La configuración persistente vive en `/opt/backups/jellyfin/config`
- Las cachés de Jellyfin y rclone viven en `/opt/jellyfin-rclone/cache`
- Si cambias de servidor, solo necesitas restaurar esas rutas y levantar Docker Compose.

---

Hecho con ❤️ por el rgdevment del presente, para el rgdevment del futuro.
