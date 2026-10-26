#!/bin/sh
# Emite o certificado wildcard <CERT_NAME> + *.<CERT_NAME> pelo desafio DNS-01 da Cloudflare.
#
#   scripts/cert-issue.sh --staging   teste (limites folgados, certificado NÃO confiável)
#   scripts/cert-issue.sh             real
#
# Comece SEMPRE pelo --staging: erro repetido no real bloqueia a emissão por horas.
# Ao emitir o real por cima de um de staging, o de staging é apagado antes.
# O nginx percebe o arquivo novo em até CERT_WATCH_INTERVAL segundos e recarrega.
. "$(dirname "$0")/lib.sh"

staging=0
[ "${1:-}" = "--staging" ] && staging=1

[ -n "${LETSENCRYPT_EMAIL:-}" ] || die "defina LETSENCRYPT_EMAIL no .env (recebe aviso de expiração)"
[ -f secrets/cloudflare.ini ] || die "falta secrets/cloudflare.ini (rode scripts/setup.sh)"
if grep -q 'COLE_O_TOKEN_AQUI' secrets/cloudflare.ini; then
    die "secrets/cloudflare.ini ainda tem o valor de exemplo: cole o token da API da Cloudflare"
fi

certbot() {
    docker compose run --rm --no-deps -T --entrypoint certbot certbot "$@"
}

renewal="data/letsencrypt/renewal/$CERT_NAME.conf"
if [ "$staging" = 0 ] && [ -f "$renewal" ] && grep -q 'acme-staging' "$renewal"; then
    info "existe um certificado de staging para $CERT_NAME: apagando antes de emitir o real"
    certbot delete --non-interactive --cert-name "$CERT_NAME"
fi

set -- certonly --non-interactive \
    --dns-cloudflare \
    --dns-cloudflare-credentials /secrets/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 30 \
    --cert-name "$CERT_NAME" \
    -d "$CERT_NAME" -d "*.$CERT_NAME" \
    -m "$LETSENCRYPT_EMAIL" --agree-tos --no-eff-email \
    --keep-until-expiring
[ "$staging" = 1 ] && set -- "$@" --staging

info "emitindo certificado para $CERT_NAME e *.$CERT_NAME ($([ "$staging" = 1 ] && echo staging || echo REAL))"
certbot "$@"

info "certificado em data/letsencrypt/live/$CERT_NAME/"
info "o nginx recarrega sozinho em até ${CERT_WATCH_INTERVAL:-300}s; para já: docker compose restart nginx"
