# User documentation

## Provided services

The stack provides a WordPress website and its administration panel over HTTPS. NGINX receives browser requests, PHP-FPM runs WordPress, and MariaDB stores posts, accounts and settings. Only HTTPS port 443 is exposed to the host.

These instructions assume the initial setup in [DEV_DOC.md](DEV_DOC.md) is complete. Known configuration issues and validation limits are listed in [README.md](README.md).

## Start and stop

Run commands from the repository root:

```sh
make          # Build images and start the stack in the background
make ps       # Show container status
make logs     # Follow logs; Ctrl+C exits the log view only
make down     # Stop and remove containers and the Compose network
```

`make down` preserves the persistent volumes and host data. Starting again with `make` should reuse the existing website and database.

Do not use `make fclean` or `make re` for routine shutdown: they remove volume registrations and images. See the developer documentation before using them.

## Access the website

The current configured domain is `thde-sou.42.fr`.

On the machine running your browser, add an entry to `/etc/hosts` using the VM's actual IP address:

```text
<VM_IP> thde-sou.42.fr
```

Replace `<VM_IP>` before saving. Use `127.0.0.1` only if the service is reachable on that machine's loopback interface, directly or through configured forwarding.

- Website: `https://thde-sou.42.fr`
- Administration panel: `https://thde-sou.42.fr/wp-admin/`

The project generates a self-signed certificate, so the browser may display a certificate warning. Confirm the address and certificate belong to your own VM before proceeding.

## Credentials

Usernames and email addresses are configured locally in `srcs/.env`:

- `WP_ADMIN_USER`: administrator account.
- `WP_USER`: second WordPress account, created with the author role.
- `MYSQL_USER`: application database account; it is not a WordPress login.

Passwords are stored locally in:

| File | Purpose |
| --- | --- |
| `secrets/wp_admin_password.txt` | Initial WordPress administrator password |
| `secrets/wp_user_password.txt` | Initial WordPress author password |
| `secrets/db_password.txt` | Application database password |
| `secrets/db_root_password.txt` | MariaDB root password |

Keep these files private and outside Git. Do not paste their contents into screenshots, logs or documentation.

For an existing WordPress installation, manage website passwords through WordPress account settings or the administrator's Users page. Editing a secret file does not update an existing account. Coordinate database password changes with the developer because the database account and WordPress connection configuration must remain synchronized.

## Check service health

1. Run `make ps`. Expect `nginx`, `wordpress` and `mariadb` to remain running. A running container alone does not prove the application is healthy.
2. Open the website and confirm a page loads.
3. Sign into `/wp-admin/` using the configured administrator account.
4. If a service exits, restarts repeatedly or the page fails, inspect its logs:

```sh
docker compose -f srcs/docker-compose.yml logs --tail=100 nginx wordpress mariadb
```

For a command-line HTTPS connectivity check:

```sh
curl -kI https://thde-sou.42.fr
```

`-k` skips certificate verification for this self-signed local setup; it does not validate certificate trust. An HTTP response confirms connectivity, but login and page checks are still needed.

If the domain cannot be found, check the hosts entry and VM IP. If the connection fails, check port 443 and container status. For a 502 response, inspect WordPress/PHP-FPM logs and then MariaDB logs.
