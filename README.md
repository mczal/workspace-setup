# workspace-setup

A collection of setup scripts and Docker Compose configurations for a local development workspace. This project provides easy setup for essential development tools including Docker, PostgreSQL, Redis, and Vim configuration.

## Contents

- **docker-compose.yml**: Docker Compose configuration for PostgreSQL 18 and Redis 8
- **docker.sh**: Script to install Docker and Docker Compose on Ubuntu
- **pivotal-vim.sh**: Script to install Pivotal's vim configuration
- **nvim-lazy.sh**: Script to install Neovim + LazyVim with our team configuration

## Prerequisites

- Ubuntu-based Linux distribution (for docker.sh script)
- sudo/administrative access
- Git (for vim setup)

## Quick Start

### 1. Docker Installation

To install Docker and Docker Compose on Ubuntu:

```bash
./docker.sh
```

**Note**: After running this script, you may need to log out and log back in (or run `newgrp docker`) for the Docker group changes to take effect.

### 2. Docker Network Setup

The Docker Compose configuration uses an external network named `my`. Create it before starting the services:

```bash
docker network create my
```

### 3. Start Services

Start PostgreSQL and Redis services:

```bash
docker-compose up -d
```

To view logs:

```bash
docker-compose logs -f
```

To stop services:

```bash
docker-compose down
```

To stop and remove volumes (⚠️ **WARNING**: This will delete all data):

```bash
docker-compose down -v
```

### 4. Vim Configuration

To install Pivotal's vim configuration:

```bash
./pivotal-vim.sh
```

This will clone the Pivotal vim-config repository to `~/.vim` and run the installation script.

### 5. Neovim + LazyVim

To install Neovim with our team's configuration:

```bash
./nvim-lazy.sh
```

Installs Neovim v0.12.5, `fd`, the JetBrainsMono Nerd Font, the LazyVim starter, and our config on top of it. Everything goes under `$HOME`; only the apt packages in step 1 need sudo.

**Note**: Restart your terminal fully afterwards. The Nerd Font is selected by the terminal emulator, not by Neovim, and a running terminal will not pick up a newly installed font. The script sets the font automatically for Terminator; for any other terminal, set it to `JetBrainsMono Nerd Font Mono` in your profile.

Re-running is safe. Neovim, `fd`, the font, and the terminal profile are skipped if already present. An existing `~/.config/nvim` is moved to a timestamped backup rather than overwritten, along with the plugin and state directories under `~/.local/share/nvim`, `~/.local/state/nvim`, and `~/.cache/nvim`.

Language servers are not installed by the script. Mason pulls each one the first time you open a matching file, so the first Ruby or TypeScript file will pause briefly. Run `:checkhealth` if anything looks wrong.

## Services

### PostgreSQL 18

- **Container**: `postgres18`
- **Port**: `5432` (bound to localhost only)
- **Credentials**:
  - User: `postgres`
  - Password: `postgres`
  - Database: `postgres`
- **Data Persistence**: Data is stored in a Docker volume `pg_data`
- **Health Check**: Configured to check PostgreSQL readiness

**Connection String Example**:
```
postgresql://postgres:postgres@localhost:5432/postgres
```

### Redis 8

- **Container**: `redis8`
- **Port**: `6379` (bound to localhost only)
- **Configuration**:
  - AOF (Append-Only File) persistence enabled
  - Memory limit: 512MB
  - Eviction policy: `allkeys-lru`
  - Save intervals configured for persistence
- **Data Persistence**: Data is stored in a Docker volume `redis_data`
- **Health Check**: Configured to ping Redis for health status

**Connection Example**:
```bash
redis-cli -h localhost -p 6379
```

## Network Security

Both PostgreSQL and Redis are bound to `127.0.0.1` (localhost only), meaning they are only accessible from the host machine, not from other machines on the network. This is a security best practice for local development environments.

## Volume Management

Data for both services is persisted in Docker volumes:

- `pg_data`: PostgreSQL data directory
- `redis_data`: Redis data directory

To inspect volumes:
```bash
docker volume ls
docker volume inspect pg_data
docker volume inspect redis_data
```

## Troubleshooting

### Docker Permission Denied

If you get permission denied errors when running Docker commands:

1. Ensure you're in the docker group: `groups $USER`
2. If not, run `newgrp docker` or log out and log back in
3. Verify with: `docker ps`

### Port Already in Use

If ports 5432 or 6379 are already in use:

1. Check what's using them: `sudo lsof -i :5432` or `sudo lsof -i :6379`
2. Stop the conflicting service or modify the port mappings in `docker-compose.yml`

### Network Not Found

If you get an error about network `my` not found:

```bash
docker network create my
```

### Services Not Starting

Check the logs for detailed error messages:

```bash
docker-compose logs postgres18
docker-compose logs redis8
```

## License

This project is provided as-is for local development setup purposes.
