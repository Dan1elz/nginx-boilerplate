#!/bin/sh
# Mostra os certificados (validade, domínios) e, com --dry-run, testa a renovação
# sem trocar nada. Teste a renovação depois de qualquer mudança no certbot.
. "$(dirname "$0")/lib.sh"

certbot() {
    docker compose run --rm --no-deps -T --entrypoint certbot certbot "$@"
}

certbot certificates
if [ "${1:-}" = "--dry-run" ]; then
    info "testando a renovação (dry-run)"
    certbot renew --dry-run --no-random-sleep-on-renew
fi
