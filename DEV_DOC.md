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

Run subsequent commands from the repository root with a user permitted to access Docker. Avoid running the Makefile with a different home directory: its directory creation uses `$(HOME)`.

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

## Storage and configuration review

The current Compose file declares:

| Volume | Container path | Host directory |
| --- | --- | --- |
| `wordpress_data` | `/var/www/html` in WordPress and NGINX | `/home/thde-sou/data/wordpress` |
| `mariadb_data` | `/var/lib/mysql` in MariaDB | `/home/thde-sou/data/mariadb` |

The Makefile creates `$HOME/data/wordpress` and `$HOME/data/mariadb`. These match Compose only when the home directory is `/home/thde-sou`. Prepare matching directories and ownership on the VM before launch, or reconcile the paths in the implementation.

The named volumes currently use local-driver `o: bind` options. Review this against the subject's prohibition on bind mounts. This remains a pending implementation issue; the documentation does not certify compliance.

Check configuration after creating the local files:

```sh
docker compose -f srcs/docker-compose.yml config --quiet
```

Resolve reported errors before building. Do not share unrestricted `docker compose config` output: configuration may contain private values.

## Build and launch

Map `thde-sou.42.fr` to the VM IP on the browser's machine, then run:

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

`make clean` stops and removes the stack and orphan containers. `make fclean` additionally removes declared volume registrations and service images. `make re` runs that cleanup and then rebuilds and launches the stack. Under the current local-driver configuration, removing volume registrations does not itself erase the host directories; this must not be treated as a backup or a reliable data-reset procedure.

NGINX configuration is copied into its image. Rebuild and recreate it after configuration changes. Existing WordPress and MariaDB data can cause initialization steps to be skipped, so recreating containers does not apply every configuration or password change to an existing installation.

## Persistence and backups

WordPress uploads, plugins, themes and `wp-config.php` persist in `wordpress_data`. Posts, accounts and site settings persist in `mariadb_data`. `wp-config.php` contains the database credential generated at initialization; protect backups accordingly.

Normal container removal preserves both sets of data. VM restart preserves them if the host storage remains intact. The configured `on-failure` policy concerns process failures; verify startup after a VM reboot explicitly.

Back up both the website files and database before destructive maintenance. Use a database-aware dump or stop the stack before copying database files to obtain a consistent backup. Store backups privately outside the directories being maintained and test restoration. Never delete host data directories as a routine cleanup step.

## Validation checklist

No runtime verification was performed as part of this documentation change. On the VM, verify:

- Compose configuration validation and image build succeed.
- Only NGINX publishes host port 443; PHP-FPM and MariaDB remain internal.
- HTTPS serves the site with TLS 1.2/1.3 and PHP requests execute correctly.
- Both WordPress accounts exist with the intended roles; administrator naming follows the subject.
- A test post and uploaded file survive `make down` followed by `make up`.
- Crash recovery and VM restart behavior are tested separately.
- Both persistent stores meet the supplied subject's named-volume requirements.
- Local credentials remain excluded from Git.

See [USER_DOC.md](USER_DOC.md) for browser access and everyday troubleshooting.
