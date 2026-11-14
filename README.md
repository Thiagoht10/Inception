*This project has been created as part of the 42 curriculum by thde-sou.*

# Inception

## Description

Inception is a system administration project that runs a WordPress website using Docker Compose inside a virtual machine. It separates the HTTPS server, PHP application and database into three containers built from project-owned Dockerfiles.

## Project description

The current implementation uses Debian Bookworm as the base image for each service:

| Service | Responsibility | Communication |
| --- | --- | --- |
| NGINX | HTTPS entry point, static files and PHP request forwarding | Host port 443; FastCGI to `wordpress:9000` |
| WordPress + PHP-FPM | Website, administration panel and PHP execution | MariaDB at `mariadb:3306` |
| MariaDB | WordPress database | Internal bridge network only |

Only NGINX publishes a host port. Its configuration permits TLS 1.2 and TLS 1.3 and uses a self-signed certificate generated during the image build. All services use the `inception` bridge network and an `unless-stopped` restart policy.

The WordPress files are shared between NGINX and WordPress through `wordpress_data`. Database files use `mariadb_data`. Compose declares ordinary named volumes. With the Docker daemon configured as described in [DEV_DOC.md](DEV_DOC.md), their host paths are `/home/thde-sou/data/docker/volumes/wordpress_data/_data` and `/home/thde-sou/data/docker/volumes/mariadb_data/_data`. Replace `thde-sou` with your learner login when configuring the VM.

### Sources and design choices

- `Makefile`: build, start, stop and inspect the stack.
- `srcs/docker-compose.yml`: services, network, secrets and storage declarations.
- `srcs/requirements/nginx/`: NGINX Dockerfile and HTTPS configuration.
- `srcs/requirements/wordpress/`: PHP-FPM configuration and WP-CLI initialization script.
- `srcs/requirements/mariadb/`: database configuration and initialization script.
- `srcs/.env`: local configuration, excluded from Git.
- `secrets/`: local password files, excluded from Git and mounted under `/run/secrets`.

Initialization creates a WordPress administrator and a second account with the author role. Existing installations are reused on subsequent starts. Password files are read during initialization; replacing them alone does not rotate existing application or database passwords.

### Virtual Machines vs Docker

A virtual machine runs a guest operating system with its own kernel. Containers isolate processes while sharing the host kernel. This project uses both: a VM provides the required environment, and Docker separates the services inside it.

### Secrets vs Environment Variables

Environment variables configure non-confidential values such as the domain, database name and usernames. Compose secrets expose passwords as files to the services that need them. Here, secret sources are local files; Compose does not provide an encrypted secret vault. Both the password files and `.env` must remain outside Git.

### Docker Network vs Host Network

A Docker bridge network provides service-name resolution and isolates internal service ports from the host unless explicitly published. Host networking shares the host network namespace. This project uses a bridge and publishes only port 443.

### Docker Volumes vs Bind Mounts

Docker volumes have a Docker-managed lifecycle and can be shared between containers. Bind mounts map a specific host path directly into a container. The current declarations use the local driver without bind options. The Docker daemon's `data-root` must be configured under `/home/<learner-login>/data` so that Docker-managed volume data resides in the location required by the subject. Verify the active daemon configuration and volume mountpoints on the VM.

## Instructions

1. Prepare a Linux VM with Docker Engine, the Docker Compose plugin and GNU Make.
2. Follow [DEV_DOC.md](DEV_DOC.md) to create `srcs/.env` and the four password files, configure Docker storage through `daemon.json`, and prepare any required migration of existing data.
3. Complete the configuration checks below before starting the stack.
4. Inside the VM, edit `/etc/hosts` with `sudo` and add `127.0.0.1 thde-sou.42.fr`, as explained in [USER_DOC.md](USER_DOC.md).
5. From the repository root, run `make`.
6. Using a browser inside the VM, open `https://thde-sou.42.fr`; the administration panel is at `/wp-admin/`. This access method requires a graphical environment and a browser in the VM.
7. Run `make down` to stop and remove the containers while preserving storage.

`make clean` also preserves the volumes. **`make fclean` deletes both named volumes and their website and database data, as well as service images. `make re` performs the same deletion before rebuilding and starting the stack.** Back up existing data before using either command.

See [USER_DOC.md](USER_DOC.md) for everyday operation and [DEV_DOC.md](DEV_DOC.md) for setup, maintenance and persistence details.

### Current validation status

This documentation was prepared from the source files; no build or running-stack validation was performed for this documentation change.

Before evaluation:

- Validate the Compose configuration.
- Verify that the active Docker `data-root` is `/home/<learner-login>/data/docker`.
- After volume creation, verify that both mountpoints are under that directory and their options contain no bind mounts. Previously created volumes retain their options until explicitly migrated or recreated.
- Verify the base-image version against the required penultimate stable release at evaluation time.
- Test startup, HTTPS, both WordPress accounts, crash recovery and persistence after container recreation and VM restart.

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose documentation](https://docs.docker.com/compose/)
- [Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Docker bridge networks](https://docs.docker.com/engine/network/drivers/bridge/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [WordPress documentation](https://wordpress.org/documentation/)
- [WP-CLI command reference](https://developer.wordpress.org/cli/commands/)
- [MariaDB documentation](https://mariadb.com/docs/)
- Inception subject, version 5.4, supplied separately for project requirements.

### AI usage

AI assisted with reading the supplied subject, inspecting the project configuration and drafting `README.md`, `USER_DOC.md` and `DEV_DOC.md`. This documentation task did not modify service configuration or validate the running infrastructure. The author must review the instructions, test the project and be able to explain its design.
