# Laravel Docker Configuration Reference

This document serves as a reference for setting up Laravel projects with Docker, based on a production-ready configuration.

## Architecture Overview

### Services

1. **app** - Laravel application (PHP 8.4 FPM + Nginx)
2. **fe** - Frontend assets compilation (Node 22)
3. **db** - PostgreSQL 17.7 database
4. **redis** - Redis 8.4 cache/session/queue storage
5. **mailcatcher** - Email testing service

## Service Details

### App Service (PHP + Nginx)

**Base Image:** `php:8.4-fpm-bookworm`

**Key Features:**
- PHP 8.4 with FPM
- Nginx web server
- Supervisor for process management
- PostgreSQL 17 client
- XDebug support (togglable via environment variable)
- Redis extension
- Composer for dependency management

**PHP Extensions:**
- pdo, pdo_pgsql - PostgreSQL database support
- opcache - PHP opcode cache
- bcmath - Arbitrary precision mathematics
- pcntl - Process control
- intl - Internationalization
- zip - ZIP archive support
- xdebug - Debugging (optional)
- redis - Redis client

**Directory Structure:**
```
.docker/
├── Dockerfile                    # Main app Dockerfile
├── entrypoint.sh                # Startup script
├── config/
│   ├── php/
│   │   ├── default.ini          # PHP configuration
│   │   └── fpm/                 # PHP-FPM pool configuration
│   ├── nginx/
│   │   ├── nginx.conf           # Nginx main config
│   │   └── default.vh.conf      # Virtual host config
│   ├── supervisor/
│   │   └── supervisord.conf     # Supervisor config
│   └── xdebug/
│       ├── xdebug-on.ini        # XDebug enabled config
│       └── xdebug-off.ini       # XDebug disabled config
```

**Entrypoint Features:**
1. Adds PostgreSQL host to `/etc/hosts` for Docker Desktop compatibility
2. Conditionally enables/disables XDebug based on `XDEBUG_ENABLED` env var
3. Creates Laravel storage symlink as www-data user
4. Starts supervisord to manage PHP-FPM and Nginx

**Environment Variables:**
- `COMPOSER_MEMORY_LIMIT: -1` - Unlimited memory for Composer
- `XDEBUG_ENABLED: true/false` - Toggle XDebug on/off
- `PROJECT_ROOT: /var/www/html` - Laravel root directory

**Ports:**
- 80 - HTTP
- 443 - HTTPS (optional)

**Health Check:**
```yaml
test: [ "CMD-SHELL", "curl --silent --fail http://localhost || exit 1" ]
interval: 30s
timeout: 10s
retries: 3
```

### FE Service (Frontend)

**Approach:** Uses official Node image with entrypoint script (no custom Dockerfile needed)

**Image:** `node:22`

**Key Configuration:**
- Runs as user `33:33` (www-data UID:GID)
- Working directory: `/var/www/html`
- Uses entrypoint script for automatic dependency installation and dev server startup
- Corepack enabled by default in Node 22 (Yarn support)

**Docker Compose Configuration:**
```yaml
fe:
  image: node:22
  working_dir: /var/www/html
  environment:
    TZ: ${APP_TIMEZONE:-UTC}
  volumes:
    - ./:/var/www/html
  entrypoint: ./.docker/config/node/entrypoint.sh
  user: "33:33"
  ports:
    - "5173:5173"
  healthcheck:
    test: [ "CMD-SHELL", "node --version" ]
    interval: 30s
    timeout: 10s
    retries: 3
```

**Entrypoint Script:**

Create `.docker/config/node/entrypoint.sh`:
```bash
#!/bin/sh
set -e

yarn install

exec yarn run dev --host
```

**Important:** Make the script executable:
```bash
chmod +x .docker/config/node/entrypoint.sh
```

**Why This Approach?**
- No custom Dockerfile needed - keeps it simple
- Entrypoint script handles startup logic automatically
- Runs as www-data (UID 33) for consistent file permissions with app service
- `exec` on the final command keeps the container running and allows proper signal handling
- Dev server watches for file changes and hot-reloads automatically
- Script is mounted from host, so changes don't require image rebuild

**How It Works:**
1. Container starts and runs entrypoint script as user 33:33 (www-data)
2. `yarn install` installs/updates dependencies
3. `exec yarn run dev --host` replaces shell with dev server process
4. Dev server stays running, watching for file changes
5. Vite/Webpack hot-reload works automatically

**Manual Commands (if needed):**
```bash
# Install specific package
docker compose exec fe yarn add <package>

# Run build
docker compose exec fe yarn build

# Run other npm/yarn commands
docker compose exec fe yarn <command>
```

**Troubleshooting:**

**Permission denied error:**
- Ensure entrypoint script has execute permissions: `chmod +x .docker/config/node/entrypoint.sh`
- Script must start with shebang: `#!/bin/sh` or `#!/bin/bash`

**Container exits immediately:**
- Make sure the final command uses `exec` to replace the shell process
- The dev server command should be the last command in the script

**Cache warnings:**
- Yarn may show warnings about cache folders - this is normal when running as non-root user
- Yarn automatically falls back to `/tmp/.yarn-cache-{uid}`

**Ports:**
- 5173 - Vite dev server (default)

### DB Service (PostgreSQL)

**Image:** `postgres:17.7-bookworm`

**Configuration:**
- Database: `${DB_DATABASE:-laravel}`
- User: `${DB_USERNAME:-laravel}`
- Password: `${DB_PASSWORD:-secret}`
- Timezone: `${APP_TIMEZONE:-UTC}`

**Volume:**
- Named volume `db17.7` for persistent data

**Port:**
- 5432 - PostgreSQL

**Health Check:**
```yaml
test: [ "CMD-SHELL", "pg_isready -U ${DB_USERNAME:-laravel}" ]
interval: 10s
timeout: 5s
retries: 5
```

### Redis Service

**Image:** `redis:8.4-bookworm`

**Usage:**
- Cache driver
- Session storage
- Queue backend

**Port:**
- 6379 - Redis

**Health Check:**
```yaml
test: [ "CMD", "redis-cli", "ping" ]
interval: 10s
timeout: 5s
retries: 3
```

### Mailcatcher Service

**Image:** `dockage/mailcatcher:0.9`

**Purpose:** Catch all outgoing emails for testing

**Ports:**
- 1080 - Web UI for viewing emails
- 1025 - SMTP server (internal)

**Laravel Configuration:**
```env
MAIL_MAILER=smtp
MAIL_HOST=mailcatcher
MAIL_PORT=1025
MAIL_ENCRYPTION=null
```

## Docker Compose Structure

### Service Dependencies

```
app
 ├── depends_on: db (healthy)
 └── depends_on: redis (healthy)
```

The app service waits for database and redis to be healthy before starting.

### Volumes

**Bind Mounts:**
- `./:/var/www/html` - Laravel application code

**Named Volumes:**
- `db17.7` - PostgreSQL data persistence

### Networks

Uses default bridge network (implicit).

## Environment Variables

Create a `.env` file with these variables:

```env
# Application
APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost
APP_TIMEZONE=UTC

# Database
DB_CONNECTION=pgsql
DB_HOST=db
DB_PORT=5432
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret

# Redis
REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

# Cache/Session/Queue
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Docker
XDEBUG_ENABLED=false
COMPOSER_MEMORY_LIMIT=-1

# Mail (Mailcatcher)
MAIL_MAILER=smtp
MAIL_HOST=mailcatcher
MAIL_PORT=1025
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"
```

## Setup Instructions

### Initial Setup

1. **Clone/Create Laravel Project**
   ```bash
   # For new project
   composer create-project laravel/laravel .

   # For existing project
   git clone <repo-url> .
   ```

2. **Copy Environment File**
   ```bash
   cp .env.example .env
   ```

3. **Build Docker Images**
   ```bash
   docker compose build
   ```

4. **Start Services**
   ```bash
   docker compose up -d
   ```

5. **Install Dependencies**
   ```bash
   docker compose exec app composer install
   docker compose exec fe npm install
   ```

6. **Generate Application Key**
   ```bash
   docker compose exec app php artisan key:generate
   ```

7. **Run Migrations**
   ```bash
   docker compose exec app php artisan migrate
   ```

8. **Build Frontend Assets**
   ```bash
   docker compose exec fe npm run build
   ```

### Daily Development

**Start all services:**
```bash
docker compose up -d
```

**View logs:**
```bash
docker compose logs -f
docker compose logs -f app
docker compose logs -f fe
```

**Stop services:**
```bash
docker compose down
```

**Restart a service:**
```bash
docker compose restart app
```

**Rebuild after config changes:**
```bash
docker compose build app
docker compose up -d app
```

### Common Commands

**Laravel Artisan:**
```bash
docker compose exec app php artisan <command>
```

**Composer:**
```bash
docker compose exec app composer <command>
```

**Database Operations:**
```bash
# Run migrations
docker compose exec app php artisan migrate

# Rollback
docker compose exec app php artisan migrate:rollback

# Fresh migration with seeding
docker compose exec app php artisan migrate:fresh --seed

# Database console
docker compose exec db psql -U laravel -d laravel
```

**Queue Worker:**
```bash
docker compose exec app php artisan queue:work
```

**Clear Cache:**
```bash
docker compose exec app php artisan cache:clear
docker compose exec app php artisan config:clear
docker compose exec app php artisan route:clear
docker compose exec app php artisan view:clear
```

**NPM/Yarn:**
```bash
docker compose exec fe npm run dev
docker compose exec fe npm run build
docker compose exec fe yarn dev
docker compose exec fe yarn build
```

## XDebug Configuration

### Enable XDebug

1. Set in `.env`:
   ```env
   XDEBUG_ENABLED=true
   ```

2. Restart app service:
   ```bash
   docker compose restart app
   ```

### Disable XDebug

1. Set in `.env`:
   ```env
   XDEBUG_ENABLED=false
   ```

2. Restart app service:
   ```bash
   docker compose restart app
   ```

### IDE Configuration

Configure your IDE to connect to XDebug on port 9003 (XDebug 3 default).

**PHPStorm:**
- Settings → PHP → Debug
- Port: 9003
- Path mappings: `/var/www/html` → `<project-root>`

## Troubleshooting

### Permission Issues

If you encounter permission issues with Laravel storage/cache:

```bash
docker compose exec app chown -R www-data:www-data storage bootstrap/cache
docker compose exec app chmod -R 775 storage bootstrap/cache
```

### Database Connection Issues

1. Ensure database service is healthy:
   ```bash
   docker compose ps
   ```

2. Check database logs:
   ```bash
   docker compose logs db
   ```

3. Verify connection from app:
   ```bash
   docker compose exec app pg_isready -h db -U laravel
   ```

### Node Modules Permission Issues

If running as different user causes issues, the FE service is configured to run as user `33:33` (www-data) for consistency.

### Port Conflicts

If ports 80, 5432, or 6379 are already in use, modify `docker-compose.yaml`:

```yaml
ports:
  - "8080:80"  # Use 8080 instead of 80
```

## Best Practices

1. **Keep It Simple:** Don't overcomplicate Docker configurations. Use official images when possible.

2. **User Permissions:** FE service runs as www-data (33:33) to match file permissions with app service.

3. **Health Checks:** Always define health checks for services that other services depend on.

4. **Environment Variables:** Use `.env` file with sensible defaults (e.g., `${VAR:-default}`).

5. **Named Volumes:** Use version-specific names (e.g., `db17.7`) to prevent conflicts when upgrading.

6. **Log Management:** Supervisor handles logs properly with appropriate permissions.

7. **XDebug Toggle:** Keep XDebug disabled in development unless actively debugging (performance).

8. **Timezone Consistency:** Set `TZ` environment variable for all services.

## Production Considerations

For production deployments:

1. Remove or disable XDebug completely
2. Use environment-specific nginx configurations
3. Enable OPcache optimizations in `php.ini`
4. Use proper secrets management (not `.env` file)
5. Enable HTTPS with proper certificates
6. Configure proper logging and monitoring
7. Use Redis for sessions in multi-container setups
8. Set up database backups
9. Use Docker secrets for sensitive data
10. Implement proper health checks in orchestration platform

## File Structure Summary

```
laravel-app/
├── .docker/
│   ├── Dockerfile              # App container definition
│   ├── entrypoint.sh          # App startup script
│   └── config/
│       ├── php/              # PHP & PHP-FPM configs
│       ├── nginx/            # Nginx configs
│       ├── supervisor/       # Supervisor configs
│       ├── xdebug/          # XDebug configs
│       └── node/
│           └── entrypoint.sh # FE entrypoint script
├── docker-compose.yaml        # Service orchestration
├── .env                       # Environment variables
└── .claude/
    └── laravel-docker-reference.md  # This file
```

## Key Takeaways

1. **Simplicity wins:** The FE service uses the official Node image with a simple entrypoint script - no custom Dockerfile needed. Keep Docker configurations as simple as possible.

2. **Permissions matter:** Running FE service as www-data (UID 33) ensures consistent file permissions across all services. Avoid permission issues by using the same user.

3. **Entrypoint scripts provide flexibility:** Using a mounted entrypoint script allows changes without rebuilding images. Remember to:
   - Make scripts executable (`chmod +x`)
   - Use `exec` on the final long-running command
   - Start scripts with proper shebang (`#!/bin/sh` or `#!/bin/bash`)

4. **Health checks are crucial:** They ensure services are truly ready before dependents start.

5. **Flexibility through environment variables:** All configurable values should use env vars with sensible defaults.

6. **Development vs Production:** Keep development setup simple; production can add complexity where needed.

7. **Troubleshooting process matters:** When facing issues, check in this order:
   - File exists at the specified path
   - File has execute permissions
   - File has correct shebang
   - Commands use `exec` properly for long-running processes

---

**Last Updated:** 2025-11-24
**Laravel Version:** 11.x
**PHP Version:** 8.4
**PostgreSQL Version:** 17.7
**Node Version:** 22
**Redis Version:** 8.4
