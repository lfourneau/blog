*This project has been created as part of the 42 curriculum by lfournea.*

# Inception

## Description

Inception is a system administration / containerization project. The goal is not to build a
website, but to learn how to design and operate a small piece of infrastructure with Docker:
writing your own Dockerfiles from a bare base image (no pre-built service images allowed),
orchestrating several containers with Docker Compose, and handling networking, persistent
storage, and secrets by hand instead of relying on defaults.

The stack itself is a classic three-tier web setup, running entirely inside a **single Docker
network**, respecting the "one process per container" principle:

- **NGINX** — the only container reachable from outside the Docker network. It terminates TLS
  (HTTPS only, self-signed certificate) and reverse-proxies PHP requests to WordPress over
  FastCGI.
- **WordPress + php-fpm** — runs the WordPress core and PHP-FPM, but ships **no web server of
  its own**; it only listens on port 9000 for FastCGI requests coming from NGINX.
- **MariaDB** — the database backing WordPress, reachable only from other containers on the
  Docker network, never exposed to the host.

Each service is built from its own `Dockerfile` starting from `debian:bookworm`, is isolated in
its own container, restarts automatically on failure, and only starts once its dependencies
report healthy (via Compose `healthcheck` + `depends_on: condition: service_healthy`).

## Instructions

### Context

This Project uses your username to create the appropriate services. For this reason consider the <user>
notation as a placeholder for your account (Using the $USER env variable). 

### Prerequisites

- Docker and the Docker Compose plugin
- `make`
- `sudo` rights (the Makefile creates data directories under `/home/<user>/data`)

### Setup

1. From the repository root, run:
   ```
   make
   ```
   This will:
   - fetch the required secret and environment files (not committed to Git, see below) if they
     are not already present,
   - create the host directories used for persistent storage,
   - add a local DNS entry so your browser can resolve `<user>.42.fr` to your own machine
     (`127.0.0.1 <user>.42.fr` in `/etc/hosts`), derived automatically from the `$USER`
     environment variable — no manual editing of `/etc/hosts` is needed,
   - build the three images and start the stack in detached mode.

2. Open `https://<user>.42.fr` in a browser. Because the TLS certificate is self-signed
   (generated at container startup, not issued by a trusted CA), the browser will show a
   security warning — the connection is still encrypted, but its identity can't be verified
   automatically. You can safely proceed past the warning for local/evaluation use.

### Makefile targets

| Target        | Effect                                                                 |
|---------------|------------------------------------------------------------------------|
| `make`        | Builds and starts all containers (fetches config/secrets on first run) |
| `make clean`  | Stops and removes the containers, **keeps** images and persisted data  |
| `make fclean` | Stops the stack, removes containers, images, and deletes persisted data|
| `make re`     | Equivalent to `make fclean` followed by `make`                         |

### Secrets and environment

Sensitive files (`secrets/credentials.txt`, `secrets/db_password.txt`,
`secrets/db_root_password.txt`, `srcs/.env`) are intentionally excluded from version control
(see `.gitignore`) and are fetched by the Makefile from a separate, private repository on first
run — they should never be committed alongside the project source.

## Resources

Classic references consulted while building this project:

- [Docker documentation](https://docs.docker.com/)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/)
- [WordPress documentation](https://developer.wordpress.org/) and
  [WP-CLI documentation](https://developer.wordpress.org/cli/commands/)
- [PHP-FPM documentation](https://www.php.net/manual/en/install.fpm.php)
- [NGINX documentation](https://nginx.org/en/docs/)
- Bash and SQL reference documentation, used while writing the setup scripts
- YouTube tutorials, notably the *TechWorld with Nana* channel, for general Docker concepts

**Use of AI:** AI assistance (Claude) was used purely as a learning aid, in a conversational,
professor-like role — to help understand *how the different pieces of the stack fit together*
(networking between containers, secrets handling, volume persistence, TLS/reverse-proxy flow),
and to answer conceptual questions while researching the topic. All project code (Dockerfiles,
Compose file, configuration files, and shell scripts) was written by hand. This README itself was
also produced with AI assistance, through a guided Q&A conversation used to verify and correct
the author's understanding of each concept before the file was generated.

## Project description

### Docker usage and project layout

```
.
├── Makefile                       fetches config/secrets, builds host dirs, drives docker compose
├── secrets/                       gitignored: DB passwords, WP admin credentials
└── srcs/
    ├── .env                       gitignored: non-sensitive configuration (hostnames, DB names, TLS subject fields)
    ├── docker-compose.yml         defines the network, volumes, secrets, and the 3 services
    └── requirements/
        ├── mariadb/               Dockerfile + my.cnf override + setup script
        ├── nginx/                 Dockerfile + nginx.conf + TLS/setup script
        └── wordpress/             Dockerfile + wp-config.php + php-fpm pool conf + setup script
```

Every image is built locally from `debian:bookworm` — no ready-made `mariadb`, `wordpress`, or
`nginx` images are used. Each service's `set-up.sh` entrypoint script performs first-run
initialization (creating the database/user, installing WordPress via WP-CLI, generating the
self-signed certificate) idempotently, so containers can be safely restarted without redoing
work that's already been done, then execs the real foreground process (`mariadbd`, `php-fpm`,
`nginx -g "daemon off;"`) as PID 1.

The main design choices were:

- **One service per container**, each with its own `Dockerfile`, restart policy, and
  healthcheck, so failures and rebuilds stay isolated to a single component.
- **A private bridge network** (`inception`) as the only channel between containers, with just
  NGINX's port 443 published to the host.
- **Named volumes anchored to fixed host paths** (`/home/<user>/data/db`,
  `/home/<user>/data/wordpress`) for the database files and WordPress code/media, so data
  survives container recreation.
- **Docker secrets** for every credential (DB passwords, WordPress admin/user credentials),
  kept out of the image, out of `.env`, and out of version control.

### Virtual Machines vs Docker

A virtual machine virtualizes hardware through a hypervisor and runs a full guest operating
system — its own kernel, init system, and libraries — on top of that virtual hardware. That
makes VMs heavy (gigabytes in size, slow to boot, real CPU/RAM overhead per instance) but gives
strong isolation: a compromised or crashed VM cannot directly touch the host's kernel.

A Docker container does not virtualize hardware at all. It's an isolated process (or process
group) running directly on the **host's existing kernel**, using Linux namespaces (PID, mount,
network, etc.) for isolation and cgroups for resource limits. Containers are therefore
lightweight, start in about a second, and only ship the application plus the userland
dependencies it needs — but because the kernel is shared with the host, the isolation boundary
is weaker than a VM's.

Inception uses Docker rather than three VMs because the exercise is specifically about the
"one lightweight, disposable, kernel-sharing process per container" model: fast rebuilds
(`docker compose up --build`), declarative orchestration, and per-service healthchecks would be
far more cumbersome to reproduce by hand-provisioning and networking three full virtual
machines.

### Secrets vs Environment Variables

Environment variables (`.env`, `env_file:` in Compose, or `ENV`/`ARG` in a Dockerfile) live in
the container's process environment. They're readable via `docker inspect`, visible to any
process inside the container through `/proc/<pid>/environ`, inherited by every child process,
and — if set at build time — baked permanently into the image's layers, readable by anyone who
can pull or export that image, even without ever running it.

Docker secrets work differently: the value is mounted as a **file** on an in-memory tmpfs at
`/run/secrets/<name>` inside the container. It is never part of the container's environment,
never stored in the image, and doesn't appear in `docker inspect`; it only exists to a process
that explicitly reads that path, and disappears once the container stops.

This project uses `.env` only for non-sensitive configuration (usernames, hostnames, TLS
certificate subject fields) and Docker secrets for every password and credential — the setup
scripts read them at runtime with `cat /run/secrets/db_password` rather than trusting an
environment variable.

### Docker Network vs Host Network

The Compose file defines a custom bridge network, `inception`, that all three services join.
On this network, Docker's embedded DNS resolves containers **by service name** — which is why
NGINX's config can say `fastcgi_pass wordpress:9000;` and WordPress's config can say
`DB_HOST = mariadb:3306` without knowing any container's actual IP address.

With `network_mode: host` instead, containers would share the host's network stack directly:
there would be no `wordpress` or `mariadb` DNS name to resolve at all (everything would have to
be hardcoded to `127.0.0.1`), all three services would compete for ports directly on the host
(collision risk with anything else running there), and MariaDB's `bind-address = 0.0.0.0` would
mean "listen on every interface of the host machine," making the database reachable from
outside the Docker network entirely — a real security regression, since MariaDB should never be
reachable from anywhere but the other two containers.

The bridge network therefore gives two things host networking does not: **isolation** (only
NGINX's port 443 is ever exposed outside the Docker network) and **service discovery** (containers
addressed by name instead of hardcoded IPs/ports).

### Docker Volumes vs Bind Mounts

Both mechanisms persist data outside a container's writable layer (unlike writing to the
container's own filesystem, which is lost as soon as the container is removed) — the difference
is who manages the storage and how portable it is:

- A **bind mount** maps an arbitrary, pre-existing path on the host directly into the container
  (e.g. `/some/host/path:/var/lib/mysql`). Docker has no awareness of it as an object; it's just
  a directory you chose, tied to that machine's exact filesystem layout, and prone to host/
  container UID-permission mismatches.
- A **named volume** is created and managed by Docker itself, tracked as a first-class object
  (`docker volume ls` / `inspect`), and referenced by a logical name in the Compose file rather
  than a hardcoded path — the same `docker-compose.yml` works on any machine regardless of where
  Docker physically stores the data.

This project actually uses a **hybrid** of the two: `DB` and `Wordpress` are declared as named
volumes under the top-level `volumes:` key (so they behave like normal Docker-managed volumes to
Compose and to the containers), but each is configured with `driver_opts` (`type: none, o: bind`)
pinning its physical storage to a specific host path under `/home/<user>/data/`. This satisfies
both constraints of the subject at once: persistent data managed through Docker's `volumes:`
mechanism, while still being inspectable at a known, fixed location on the host filesystem.
