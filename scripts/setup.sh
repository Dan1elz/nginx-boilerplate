#!/bin/sh
# Prepara a VM para o proxy. Idempotente: pode rodar quantas vezes quiser.
#   - rede proxy-net
#   - pastas data/ e secrets/
#   - .env e secrets/cloudflare.ini a partir dos modelos (sem sobrescrever)
#   - listas de IP da Cloudflare, se ainda não existirem
. "$(dirname "$0")/lib.sh"

if docker network inspect proxy-net >/dev/null 2>&1; then
    info "rede proxy-net já existe"
else
    info "criando a rede proxy-net"
    docker network create proxy-net >/dev/null
fi

mkdir -p data/letsencrypt secrets
chmod 700 secrets

if [ ! -f .env ]; then
    cp .env.example .env
    info ".env criado a partir do .env.example (revise LETSENCRYPT_EMAIL e as portas)"
fi

if [ ! -f secrets/cloudflare.ini ]; then
    cp certbot/cloudflare.ini.example secrets/cloudflare.ini
    warn "secrets/cloudflare.ini criado com valor de exemplo: cole o token da Cloudflare antes de emitir o certificado"
fi
# O certbot se recusa a usar o arquivo se outros usuários puderem ler
chmod 600 secrets/cloudflare.ini

if [ ! -s nginx/snippets/cloudflare-geo.conf ] || [ ! -s nginx/snippets/cloudflare-realip.conf ]; then
    "$ROOT/scripts/update-cloudflare-ips.sh" --no-reload
fi

info "pronto. Próximo passo: docker compose up -d --build"
