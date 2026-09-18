# Developer Documentation

This document is for anyone setting up, building, or maintaining the Inception stack itself.
For end-user/administrator instructions (logging in, checking the site is up), see
[`USER_DOC.md`](./USER_DOC.md); for the project's overall goals and design rationale (VM vs
Docker, secrets vs env vars, network and volume choices), see [`README.md`](./README.md).

## Setting up the environment from scratch

### Prerequisites

- Docker Engine and the Docker Compose plugin (`docker compose`, not the standalone `docker-compose`)
- `make`
- `sudo` rights (the Makefile creates host directories under `/home/lfournea/data` and, on
  `fclean`, removes them)
- `git` (used by the Makefile to fetch config/secrets on first run)

### Configuration files and secrets

Two categories of configuration are intentionally kept out of version control (see
`.gitignore`):

- `srcs/.env` — non-sensitive configuration: WordPress DB username (`WORDPRESSUSER`),
  database name (`WORDPRESSDATABASE`), and the fields used to generate the self-signed TLS
  certificate (`COUNTRY`, `STATE`, `LOCATION`, `ORGANIZATION`).
- `secrets/credentials.txt`, `secrets/db_password.txt`, `secrets/db_root_password.txt` —
  sensitive values: WordPress account credentials and database passwords, consumed at runtime
  via Docker secrets (mounted at `/run/secrets/<name>` inside the containers, never baked into
  images or exposed as environment variables).

On a fresh clone, running `make` fetches all of these automatically from a separate, private
repository (see the `$(CONFIG_FILES):` rule in the `Makefile`) if they aren't already present
locally.

## Building and launching

### Via the Makefile (recommended)

```
make
```

This is the standard entry point: it fetches missing config/secrets, creates the host data
directories, then runs `docker compose up --build -d` from `srcs/`.

### Via Docker Compose directly

Once `secrets/` and `srcs/.env` are in place, you can bypass the Makefile for finer-grained
control (always run these from the `srcs/` directory, where `docker-compose.yml` lives):

```
docker compose up --build -d        # build (if needed) and start all services, detached
docker compose up --build -d wordpress   # rebuild and restart only the wordpress service,
                                          # leaving mariadb and nginx untouched
docker compose build wordpress      # rebuild an image without restarting the container
docker compose down                 # stop and remove containers, keep images and volumes
docker compose down --rmi all -v    # stop, remove containers, images, AND volumes (data loss)
```

Startup order is enforced by `depends_on: condition: service_healthy` in `docker-compose.yml`:
`wordpress` won't start until `mariadb` reports healthy, and `nginx` won't start until both
`mariadb` and `wordpress` report healthy.

## Managing containers and volumes

Useful commands for day-to-day development and debugging (run from `srcs/` unless noted):

| Task                                               | Command                                                 |
|--------------------------------------------------- |---------------------------------------------------------|
| List containers and their status/health            | `docker compose ps`                                     |
| Tail logs for one service                          | `docker compose logs -f wordpress`                      |
| Get a shell inside a running container             | `docker exec -it <container_id> bash`                   |
| Rebuild and restart just one service               | `docker compose up --build -d <service>`                |
| Stop everything, keep images/volumes               | `docker compose down`                                   |
| Stop everything and wipe images + volumes          | `docker compose down --rmi all -v`                      |
| List Docker volumes                                | `docker volume ls`                                      |
| Inspect a volume's host path/usage                 | `docker volume inspect <volume_name>`                   |

Note on volume naming: since `docker-compose.yml` doesn't set an explicit `name:` on the `DB`/
`Wordpress` volumes, Compose prefixes them with the project name derived from the `srcs/`
directory — expect to see them listed as `srcs_DB` / `srcs_Wordpress` in `docker volume ls`,
not the bare names used inside the compose file.

## Where project data is stored, and how it persists

`mariadb`'s and `wordpress`'s volumes are declared as Docker-managed named volumes, but each is
configured (via `driver_opts`) to physically store its data at a fixed path on the host:

- MariaDB data → `/home/<user>/data/db` on the host
- WordPress core files/media → `/home/<user>/data/wordpress` on the host

You can confirm this at any time with `docker volume inspect srcs_DB` (or `srcs_Wordpress`) and
checking the `Options.device` field.

Because these are real volumes (not just container filesystem writes), the data **survives**
container restarts and `docker compose down` / `make clean`. It is only deleted by
`docker compose down -v` (or `--rmi all -v`) or `make fclean`, which explicitly remove the
volumes and their underlying host directories — that's the one operation on this project that is
genuinely destructive to site content.
