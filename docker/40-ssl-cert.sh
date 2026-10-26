#!/bin/sh
# Antes do nginx subir: define qual certificado usar (ver select-cert).
set -eu
origin="$(select-cert)"
echo "$0: certificado em uso: $origin (${CERT_NAME:-example.com})"
if [ "$origin" = selfsigned ]; then
    echo "$0: AVISO: certificado provisório. Emita o real com scripts/cert-issue.sh" >&2
fi
