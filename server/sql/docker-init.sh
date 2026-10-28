#!/bin/sh
set -eu

# Use long alphanumeric passwords in .env; avoid single quotes in these local bootstrap values.
case "$REGISTRY_PASSWORD$PROVISIONER_PASSWORD" in
  *"'"*) echo "Las contraseñas de bootstrap no deben contener comillas simples." >&2; exit 1 ;;
esac

psql --set=ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<EOSQL
CREATE ROLE nova_registry_user LOGIN PASSWORD '$REGISTRY_PASSWORD';
CREATE DATABASE nova_registry OWNER nova_registry_user;
CREATE ROLE nova_provisioner LOGIN CREATEDB PASSWORD '$PROVISIONER_PASSWORD';
GRANT CONNECT ON DATABASE nova_registry TO nova_registry_user;
EOSQL
