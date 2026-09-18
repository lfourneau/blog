# User Documentation

This document is for anyone who needs to **use or administer** the running Inception stack,
without necessarily touching Docker or code directly. For build/development details, see
[`DEV_DOC.md`](./DEV_DOC.md); for the project's overall goals and design, see
[`README.md`](./README.md).

## What the stack provides

From a user's point of view, this stack provides exactly one thing: a **WordPress website,
reachable securely over HTTPS**. Behind the scenes it's actually made up of three components
(a reverse proxy, WordPress itself, and a database) — but those are implementation details;
day-to-day, there is just the one website to log into and manage through WordPress's own
interface.

## Starting and stopping the project

The project is controlled through `make`, run from the repository root:

| Command       | Effect                                                                   |
|---------------|---------------------------------------------------------------------------|
| `make`        | Starts the website (builds images on first run, then starts all containers) |
| `make clean`  | Stops the website, but **keeps** all site content and images              |
| `make fclean` | Stops the website and **permanently deletes** all site content and images |
| `make re`     | Fully resets and restarts the website (`fclean` then `make`)              |

Use `make clean` for a normal stop (e.g. maintenance, reboot) since it preserves everything.
Only use `make fclean` when you deliberately want to wipe the site and start over — this cannot
be undone.

## Accessing the website and the administration panel

Once the stack is running, the site is reachable at (no manual `/etc/hosts` editing is required —
`make` adds the DNS entry automatically based on the `$USER` environment variable, see
`README.md`):

- **Website:** `https://<user>.42.fr`
- **Login page:** `https://<user>.42.fr/wp-login.php`
- **Admin dashboard:** `https://<user>.42.fr/wp-admin/`

Your browser will show a security warning the first time you visit — this is expected. The
site's TLS certificate is self-signed rather than issued by a public certificate authority, so
the connection is encrypted but the browser can't automatically verify the site's identity. You
can safely continue past the warning.

Two WordPress accounts exist by default:

- An **administrator** account, which can create/edit pages, manage plugins and settings, and
  manage other users.
- A **subscriber** account, which can view content and leave comments, but cannot create or
  edit pages.

The actual usernames and passwords for both accounts are not listed here — see
"Locating credentials" below.

## Locating and managing credentials

All sensitive credentials are kept in the `secrets/` directory at the repository root, **outside
of version control** (they are not committed to Git). Three files are relevant:

| File                          | Contents                                                        | Who needs it                              |
|--------------------------------|-------------------------------------------------------------------|---------------------------------------------|
| `secrets/credentials.txt`      | WordPress admin and subscriber usernames, passwords, and emails | Anyone logging into the website             |
| `secrets/db_password.txt`      | Password for the WordPress database user                        | Database administration only, not day-to-day use |
| `secrets/db_root_password.txt` | MariaDB root (superuser) password                                | Database administration only, not day-to-day use |

To log into the website, open `secrets/credentials.txt` for the account username and password.
The two database password files can be ignored unless you're specifically troubleshooting or
administering the database itself.

**Do not** share these files or commit them to a public repository — treat them the same as any
other password.

## Checking that services are running correctly

The simplest check requires no technical tools at all: open `https://<user>.42.fr` in a
browser. If the page loads (after accepting the expected certificate warning), the site is
working.

For a more technical check, on the machine running the stack:

```
docker compose ps
```

(run from the `srcs/` directory). This lists each of the three containers with a status column.
Two of them (`mariadb` and `wordpress`) report a health state such as `healthy`,
`unhealthy`, or `health: starting`; `nginx` will simply show as `Up`. If all reported containers
show `Up`/`healthy` and the site loads in a browser, the stack is working correctly. If a
container shows `unhealthy`, `Restarting`, or is missing from the list entirely, something needs
attention — see `DEV_DOC.md` for how to inspect logs and diagnose further.
