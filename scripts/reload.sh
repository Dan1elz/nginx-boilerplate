#!/bin/sh
# Valida e recarrega a config sem derrubar conexões. Config inválida não é aplicada.
. "$(dirname "$0")/lib.sh"
nginx_running || die "nginx não está rodando (docker compose up -d)"
nginx_test
docker compose exec -T nginx nginx -s reload
info "recarregado"
