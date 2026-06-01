# Docker Web Development Environment

This folder defines the Docker containers for your web development workflow. Docker through this `ops` project is the only supported local development path.

Your project source lives outside this folder:

```txt
/Users/mariomedrano/Projects/ajedrezlapaz/web
```

This Docker setup lives here:

```txt
/Users/mariomedrano/Projects/ajedrezlapaz/ops
```

## Containers

The development Compose stack has three main containers:

- `ws`: your interactive development machine with terminal tools.
- `dev-web`: runs the `ajedrezlapaz` Next.js app in development mode.
- `dev-api`: runs the Elysia API with Bun, SQLite, and Redis (rate limiting).

Production-like local testing lives in `docker-compose.prod.yml`:

- `prod-web`: builds and runs the `ajedrezlapaz` Next.js app in production mode.
- `prod-api`: builds and runs the Elysia API in production mode with Redis.

All custom images use Debian Bookworm slim bases through `oven/bun:1-debian`.

## How The Containers Connect

`ws` mounts your host projects directory:

```txt
/Users/mariomedrano/Projects/ajedrezlapaz/web -> /alp/web
/Users/mariomedrano/Projects/ajedrezlapaz/api -> /alp/api
/Users/mariomedrano/Projects/ajedrezlapaz/ops -> /alp/ops
```

So inside `ws`, your app path is:

```txt
/alp/web
```

`dev-web` mounts only that app:

```txt
/Users/mariomedrano/Projects/ajedrezlapaz/web -> /alp/web
```

`dev-api` mounts your API project:

```txt
/Users/mariomedrano/Projects/ajedrezlapaz/api -> /alp/api
```

`prod-web` and `prod-api` use the app folders as Docker build contexts from the standalone `docker-compose.prod.yml` file.

The result:

- edit code in `ws`
- run the integrated dev stack with `dev-web` and `dev-api` together
- regenerate web API types from the fresh `dev-api` Swagger schema during startup
- build/run production-like images with `prod-web` and `prod-api`

Runtime configuration lives in this folder:

- `ops/.env` is the local source of truth for Docker dev and production-like local runs.
- `ops/.env.example` documents the required variables.
- `web/.env.local` and `api/.env` are intentionally not used by the supported dev workflow.

## WS

`ws` includes:

- `zsh`
- `tmux`
- Neovim
- `git`
- `lazygit`
- Bun
- nvm
- default Node.js LTS through nvm
- Deep Code CLI
- TypeScript, TSX, Create Next App
- `tree-sitter-cli` for Neovim parser builds
- SQLite CLI and development headers
- `ripgrep`, `fd`, `fzf`, `jq`, `yq`, `bat`, `tree`, `htop`

The image does not bake in shell, tmux, Neovim, or lazygit config files. Your dotfiles repo should own those.

This setup uses your Linux workstation dotfiles fork from:

```txt
/Users/mariomedrano/Dev/.dotfiles -> /alp/dotfiles
```

Inspect before symlinking:

```sh
find /alp/dotfiles -maxdepth 3 -type f | sort
```

Link the active ws configs into the home directory:

```sh
mkdir -p ~/.config
ln -s /alp/dotfiles/.zshrc ~/.zshrc
ln -s /alp/dotfiles/.config/nvim ~/.config/nvim
ln -s /alp/dotfiles/.config/tmux ~/.config/tmux
ln -s /alp/dotfiles/.config/lazygit ~/.config/lazygit
```

The dotfiles originally came from Lazar Nikolov's macOS-oriented dotfiles, but this branch keeps only the Linux container pieces used by `ws`.

Deep Code settings are generated from your private dotfiles environment file:

```txt
/Users/mariomedrano/Dev/.dotfiles/.env -> /home/mario/.deepcode/settings.json
```

Use `/Users/mariomedrano/Dev/.dotfiles/.env.example` as the template. The real `.env` is ignored by git.

Then clone your project:

```sh
cd /alp
git clone git@github.com:YOUR_USER/ajedrezlapaz.git web
```

That writes to:

```txt
/Users/mariomedrano/Projects/ajedrezlapaz/web
```

For the API, clone or create:

```sh
cd /alp
git clone git@github.com:YOUR_USER/ajedrezlapaz-api.git api
```

That writes to:

```txt
/Users/mariomedrano/Projects/ajedrezlapaz/api
```

## Quick Start

Copy the example environment file and fill the local Docker values:

```sh
cp .env.example .env
```

Start the independent workstation:

```sh
make up-ws
```

Open a shell in `ws`:

```sh
make shell
```

Start the integrated app stack:

```sh
make up
```

This starts/recreates:

- `dev-api`
- `dev-web`

It starts the pair if needed. `dev-api` applies pending migrations before serving, then the ops sync waits for Swagger from inside the Docker network and regenerates the web API types.

That Swagger/type sync is implemented in:

```sh
scripts/sync-api-types.sh
```

After changing API routes, response schemas, or Swagger-visible contracts, run:

```sh
make up
```

To refresh or check generated types without recreating the app stack:

```sh
make api-types
make api-types-check
```

From inside `ws`, the same script can update the mounted web project as long as `dev-api` is already running:

```sh
/alp/ops/scripts/sync-api-types.sh
/alp/ops/scripts/sync-api-types.sh --check
```

Stop the integrated app stack:

```sh
make down
```

Stop the independent workstation:

```sh
make down-ws
```

Display the development command reference:

```sh
make help
```

## GitHub SSH From WS

This setup treats `ws` as your real development machine, so GitHub SSH should live inside the container. That keeps `git`, `lazygit`, private clones, pulls, and pushes working from the same place where you use `tmux` and Neovim.

The SSH key is stored in the persistent `ws-home` Docker volume at `/home/mario/.ssh`, so it survives image rebuilds. If you delete Docker volumes with `make clean`, you will need to recreate the key.

Inside the ws container:

```sh
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "mario@web-dev" -f ~/.ssh/id_ed25519_github
cat > ~/.ssh/config <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_github
  IdentitiesOnly yes
  AddKeysToAgent no
EOF
chmod 600 ~/.ssh/config ~/.ssh/id_ed25519_github
cat ~/.ssh/id_ed25519_github.pub
```

Add the printed public key to GitHub under SSH keys, then verify:

```sh
ssh -T git@github.com
```

Run the integrated app stack:

```sh
make up
```

Open:

```txt
http://localhost:3000
```

## Backend API

`dev-api` expects an Elysia/Bun API at:

```txt
/Users/mariomedrano/Projects/ajedrezlapaz/api
```

Inside the container, SQLite lives at:

```txt
/alp/api/data/app.db
```

The app receives one SQLite source of truth:

```txt
SQLITE_PATH=/alp/api/data/app.db
```

Drizzle derives `DATABASE_URL=file:${SQLITE_PATH}` internally.

### Redis (rate limiting)

Login rate limiting uses Redis for per-username and per-IP counters. Redis runs as a lightweight side process **inside the API container** — no separate service, no persistence.

| Config | Default | Purpose |
|--------|---------|---------|
| `REDIS_URL` | `redis://localhost:6379` | Redis connection string |

Startup order in the API container:

```text
redis-server (daemonized, no persistence) → readiness check (redis-cli ping) → db:migrate → bun start
```

Redis is started with flags that disable persistence (`--save "" --appendonly no`) since rate-limit counters are ephemeral and expire automatically after the 15-minute window. No cleanup jobs needed.

When Redis is unreachable the API fails open: rate limiting is skipped, and only a 500ms artificial delay protects against brute-force attempts. Redis recovers automatically within 30 seconds of becoming available again.

### Environment Variables

All API runtime configuration is passed through the Docker Compose environment blocks from `ops/.env`.

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `CSRF_SECRET` | Yes | — | HMAC key for CSRF token signing |
| `INTERNAL_API_SECRET` | Yes | — | Shared secret for internal API communication (via X-Internal-Secret header) |
| `REDIS_URL` | No | `redis://localhost:6379` | Redis connection for rate limiting and tokens |
| `RESEND_API_KEY` | Production only | — | Resend API key for email delivery (fails fast if missing in prod) |
| `EMAIL_FROM` | No | `noreply@support.ajedrezlapaz.com` | Sender address for verification and reset emails |
| `FRONTEND_URL` | Yes | — | Allowed CORS origin (comma-separated) |
| `NODE_ENV` | No | `development` | Controls cookie Secure flag and session cookie name |

In development, `RESEND_API_KEY` defaults to empty (emails are not sent but the API does not crash). In production (`docker-compose.prod.yml`), it uses `${RESEND_API_KEY:?}` and fails fast when the key is not set.

Run the integrated app stack:

```sh
make up
```

Open:

```txt
http://localhost:4000
```

Open a shell in the API container:

```sh
make shell-api
```

Open the SQLite database:

```sh
make sqlite-api
```

Apply migrations:

```sh
make db-migrate
```

Seed development fixture data:

```sh
make db-seed
```

Reset the dev SQLite database, then migrate and seed it:

```sh
make db-reset
```

## Production

`prod-web` expects your Next.js app at:

```txt
/Users/mariomedrano/Projects/ajedrezlapaz/web
```

It uses Bun, runs the app build, and starts the Next.js standalone server with Bun on port `8080`.

For best production output, your app should set this in `next.config.mjs` or `next.config.js`:

```js
const nextConfig = {
  output: "standalone",
};

export default nextConfig;
```

Run production:

```sh
docker compose -f docker-compose.prod.yml up --build prod-web prod-api
```

Or:

```sh
make prod
```

Open:

```txt
http://localhost:8080
http://localhost:8081
```

Run only the web production container:

```sh
make prod-web
```

Run only the API production container:

```sh
make prod-api
```

## Notes

Development SQLite data is stored in the `dev-api-sqlite-data` Docker volume. Production API SQLite data is stored in the `prod-api-sqlite-data` Docker volume. If you run `docker compose down -v`, both local API databases are deleted.

If Docker Desktop cannot mount `/Users/mariomedrano/Projects/ajedrezlapaz`, add that path to Docker Desktop file sharing settings, or change `WEB_PATH`, `API_PATH`, `OPS_PATH`, or `DOTFILES_PATH` in `.env`.

The `ws-home` volume is mounted at `/home/mario` and keeps your dotfiles clone, shell history, LazyVim plugins, and tool state between rebuilds.

To reset all Docker volumes:

```sh
docker compose down -v
```
