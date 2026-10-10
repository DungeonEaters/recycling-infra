# Recycling Infrastructure

Docker Compose, Caddy, environment templates and Dev Container configuration for the Recycling platform.

## Local development

Run from this directory:

```bash
make up
```

Compose builds the sibling repositories:

- `../recycling-backend`
- `../recycling-web`
- `../recycling-mobile`

Endpoints: API `http://localhost:8000`, admin panel `http://localhost:5173`, driver app `http://localhost:5174`.

## Production

`docker-compose.prod.yml` runs immutable images from GHCR behind Caddy. Set secrets in an untracked `.env.production` before deployment.
