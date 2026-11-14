# Developer documentation

## Environment from scratch

Use a Linux virtual machine with Docker Engine, the Docker Compose plugin, GNU Make and access to package repositories and WordPress/WP-CLI downloads. The current Dockerfiles use Debian Bookworm and PHP 8.2 paths. Confirm base-image eligibility against the supplied subject before evaluation.

Verify prerequisites:

```sh
docker --version
docker compose version
make --version
docker info
```

Run subsequent commands from the repository root with a user permitted to access Docker. The Makefile delegates to Docker Compose; volume storage is managed by Docker using the daemon configuration described below.

## Local configuration

Create `srcs/.env` with non-confidential configuration. This is a template; replace the example values as needed:

```dotenv
DOMAIN_NAME=thde-sou.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_service
WP_TITLE=Inception
WP_ADMIN_USER=site_owner
WP_ADMIN_EMAIL=owner@example.com
WP_USER=site_author
WP_USER_EMAIL=author@example.com
```

The administrator username must not contain `admin` or `administrator`, including case variants. Use a non-root database user. The initialization script permits letters, digits and underscores in the database name, and additionally hyphens in the database username.

The domain is also fixed in the NGINX configuration and certificate-generation command. Changing only `DOMAIN_NAME` does not update those files or an already installed WordPress site's URL.

Create `secrets/` and populate these files locally with separate, non-empty passwords:

```text
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

Use an editor or password manager to write the values without placing passwords in shell history. Restrict the directory and files to the owner (`chmod 700 secrets` and `chmod 600 secrets/*.txt`). The existing `.gitignore` excludes `/secrets/` and `/srcs/.env`.

Check exclusion without displaying contents:

```sh
git check-ignore srcs/.env secrets/*.txt
```

Compose mounts the passwords under `/run/secrets/` in the relevant containers. WordPress receives three secrets; MariaDB receives the database user and root secrets. NGINX receives none.

## Storage and Docker daemon configuration

The Compose file declares two Docker-managed named volumes without `driver_opts` or bind mounts. Their host location depends on the Docker daemon's `data-root` setting.

The supplied subject requires the volume data to reside under `/home/login/data`, with `login` replaced by the learner's username. It does not prescribe names or nesting levels for directories inside `data`. Configuring `data-root` as `/home/thde-sou/data/docker` therefore places both stores under the required directory. Replace `thde-sou` with your own learner login throughout these instructions.

### Configure a fresh VM

These instructions assume Docker Engine running as a system service on a Linux VM with systemd, not rootless Docker or Docker Desktop.

1. Check the service and create the configuration and storage directories:

   ```sh
   sudo systemctl status docker --no-pager
   sudo mkdir -p /etc/docker /home/thde-sou/data/docker
   sudo nano /etc/docker/daemon.json
   ```

2. If the file is empty, save this JSON. If it already contains settings, preserve them and add or update `data-root` within the existing JSON object:

   ```json
   {
     "data-root": "/home/thde-sou/data/docker"
   }
   ```

   Use an absolute path: this file does not expand `${HOME}` as Compose does. In Nano, save with Ctrl+O, confirm with Enter, then exit with Ctrl+X.

3. Validate the file:

   ```sh
   sudo dockerd --validate --config-file=/etc/docker/daemon.json
   ```

   Continue only after `configuration OK`. For an existing installation, complete the migration preparation below before restarting Docker.

4. Apply the configuration and verify the active directory:

   ```sh
   sudo systemctl restart docker
   sudo docker info --format '{{.DockerRootDir}}'
   ```

   The expected result is `/home/thde-sou/data/docker`. Creating the JSON file alone does not activate this setting. The setting affects the entire Docker daemon, not only this project.

If Docker fails to start, inspect the error before proceeding:

```sh
sudo systemctl status docker --no-pager -l
sudo journalctl -u docker.service -n 60 --no-pager
```

See the Docker documentation for [daemon configuration](https://docs.docker.com/engine/daemon/) and [startup troubleshooting](https://docs.docker.com/engine/daemon/troubleshoot/).

### Volume locations and the Makefile

After the stack creates the volumes with the configuration above, their expected locations are:

| Volume | Container path | Host directory |
| --- | --- | --- |
| `wordpress_data` | `/var/www/html` in WordPress and NGINX | `/home/thde-sou/data/docker/volumes/wordpress_data/_data` |
| `mariadb_data` | `/var/lib/mysql` in MariaDB | `/home/thde-sou/data/docker/volumes/mariadb_data/_data` |

Docker creates and manages these volume directories. The Makefile no longer creates `$HOME/data/wordpress` or `$HOME/data/mariadb`; these paths are unused by the current Compose configuration. If they remain from an older installation, check and back up their contents before removing them.

After launch, verify the actual mountpoints and options:

```sh
docker volume inspect --format '{{.Name}}: {{.Mountpoint}} options={{json .Options}}' wordpress_data mariadb_data
```

The mountpoints must be under the configured directory, and the volume options must not include `o: bind`. Changing Compose does not convert previously created volumes with bind options into ordinary named volumes.

### Existing installations and migration

Changing `data-root` does not move existing images, containers or volumes. Do not restart Docker with the new setting until existing data has been backed up and a migration has been prepared. Keep the previous daemon configuration and storage intact until restoration is verified.

For a project previously using `o: bind`, back up both the WordPress files and MariaDB data from their actual existing locations. Use a database dump or stop the stack before copying database files. After switching to the new storage root, create ordinary named volumes and restore the backups into them before starting the application. Preserve file ownership and permissions. Copying only the old Docker storage directory does not convert bind-backed volumes or migrate their external data.

This documentation does not establish that a migration has been performed on any VM. Verify the active Docker root and volume options on the target machine before launching the project.

Check configuration after creating the local files:

```sh
docker compose -f srcs/docker-compose.yml config --quiet
```

Resolve reported errors before building. Do not share unrestricted `docker compose config` output: configuration may contain private values.

## Build and launch

Inside the VM, edit `/etc/hosts` using `sudo nano /etc/hosts` and add this line while preserving existing entries:

```text
127.0.0.1 thde-sou.42.fr
```

Use your learner login consistently with the domain configured for the project. This access method uses a browser inside the VM and requires a graphical environment there. The physical school computer does not need an `/etc/hosts` change.

From the repository root inside the VM, run:

```sh
make build    # Build only
make up       # Build and start in the background; also the default make target
make ps
```

NGINX generates a self-signed certificate at image build time. WordPress waits for MariaDB, downloads WordPress if missing, creates `wp-config.php` if missing, installs the site if needed and creates the author if absent. MariaDB initializes its system tables if needed and uses `/var/lib/mysql/.inception-initialized` to record completed project initialization.

`depends_on` declares startup ordering; it does not by itself prove database readiness. The WordPress script supplies its own database wait. The services then run NGINX, PHP-FPM and MariaDB in the foreground.

## Manage containers and volumes

```sh
make logs
make down
make clean

docker compose -f srcs/docker-compose.yml logs --tail=100 wordpress
docker compose -f srcs/docker-compose.yml restart nginx
docker compose -f srcs/docker-compose.yml exec wordpress wp user list --allow-root
docker volume inspect wordpress_data mariadb_data
```

`make clean` stops and removes the stack and orphan containers while preserving named volumes. `make fclean` uses `down -v` and removes the declared named volumes, including their data, as well as service images. `make re` runs that destructive cleanup and then rebuilds and launches the stack. With ordinary Docker-managed volumes, both `make fclean` and `make re` delete persistent project data; back up before using them.

NGINX configuration is copied into its image. Rebuild and recreate it after configuration changes. Existing WordPress and MariaDB data can cause initialization steps to be skipped, so recreating containers does not apply every configuration or password change to an existing installation.

## Persistence and backups

WordPress uploads, plugins, themes and `wp-config.php` persist in `wordpress_data`. Posts, accounts and site settings persist in `mariadb_data`. `wp-config.php` contains the database credential generated at initialization; protect backups accordingly.

Normal container removal preserves both sets of data. VM restart preserves them if the host storage remains intact. All three services use `restart: unless-stopped`: existing containers restart after failures and Docker daemon restarts unless they were explicitly stopped. Containers removed by `make down` must be recreated with `make up`. Ensure the Docker service starts on boot and verify behavior after a VM reboot.

Back up both the website files and database before destructive maintenance. Use a database-aware dump or stop the stack before copying database files to obtain a consistent backup. Store backups privately outside the directories being maintained and test restoration. Never delete host data directories as a routine cleanup step.

## Validation checklist

No runtime verification was performed as part of this documentation change. On the VM, verify:

- Compose configuration validation and image build succeed.
- Only NGINX publishes host port 443; PHP-FPM and MariaDB remain internal.
- HTTPS serves the site with TLS 1.2/1.3 and PHP requests execute correctly.
- Both WordPress accounts exist with the intended roles; administrator naming follows the subject.
- A test post and uploaded file survive `make down` followed by `make up`.
- Crash recovery and VM restart behavior are tested separately.
- The active Docker root is `/home/<learner-login>/data/docker`, and both volume mountpoints are beneath it with no bind options.
- Existing data has been restored and checked if this VM was migrated from an older configuration.
- Local credentials remain excluded from Git.

See [USER_DOC.md](USER_DOC.md) for browser access and everyday troubleshooting.
