FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm
# The base image ships a stale yarn apt source whose key is not installed; drop it so apt-get update succeeds.
RUN rm -f /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*
