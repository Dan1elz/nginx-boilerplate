#!/bin/sh
# Cria nginx/sites/<hostname>.conf para um projeto novo.
#
#   scripts/new-site.sh <hostname> <alias:porta> [web|api|s3]
#
#   web  (padrão) front/SPA: página de erro em HTML, WebSocket com timeout longo
#   api  rate limit por IP, erros em JSON
#   s3   storage S3: sem limite de upload, sem buffer, Host e caminho intactos
#
# Exemplo: scripts/new-site.sh meuprojeto.example.com meuprojeto-web:80
# Depois: scripts/reload.sh e scripts/test-sites.sh
. "$(dirname "$0")/lib.sh"

[ $# -ge 2 ] || die "uso: $0 <hostname> <alias:porta> [web|api|s3]"
host="$1"
upstream="$2"
kind="${3:-web}"

case "$host" in
    *.*.*.*) die "$host tem dois níveis abaixo do domínio: o wildcard *.$CERT_NAME não cobre. Use <projeto>-<servico>.$CERT_NAME" ;;
    *."$CERT_NAME") ;;
    *) warn "$host não termina em .$CERT_NAME: o certificado atual não vale para ele" ;;
esac
case "$upstream" in
    *:[0-9]*) ;;
    *) die "upstream precisa de porta: <alias>:<porta> (ex.: meuprojeto-web:80)" ;;
esac

name="${host%%.*}"
file="nginx/sites/$name.conf"
[ -e "$file" ] && die "$file já existe"

case "$kind" in
    web)
        errors=html
        extra=""
        location='    location / {
        proxy_pass $upstream;
        include /etc/nginx/snippets/proxy.conf;
        # WebSocket (HMR do Vite, etc.) fica aberto; sem isso cai a cada 60s
        proxy_read_timeout 1h;
    }'
        ;;
    api)
        errors=json
        extra='
    client_max_body_size 10m;
'
        location='    location / {
        limit_req zone=per_ip burst=50 nodelay;
        proxy_pass $upstream;
        include /etc/nginx/snippets/proxy.conf;
    }'
        ;;
    s3)
        errors=html
        extra='
    # URL assinada: Host e caminho não podem mudar. Sem limite e sem buffer
    client_max_body_size 0;
    proxy_buffering off;
    proxy_request_buffering off;
'
        location='    location / {
        proxy_pass $upstream;
        include /etc/nginx/snippets/proxy.conf;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }'
        ;;
    *) die "tipo desconhecido: $kind (web, api ou s3)" ;;
esac

cat > "$file" <<EOF
# $host → $upstream ($kind)
# Criado por scripts/new-site.sh em $(date +%Y-%m-%d).
server {
    listen 443 ssl;
    http2 on;
    server_name $host;

    include /etc/nginx/snippets/site.conf;
    include /etc/nginx/snippets/errors-$errors.conf;
$extra
    set \$upstream http://$upstream;

$location
}
EOF

info "criado $file"
cat <<EOF

Falta:
  1. DNS: registro A $host → IP da VM, com proxy (nuvem laranja)
  2. No compose do projeto, no serviço público: sem "ports", rede proxy-net (external)
     e alias ${upstream%%:*}
  3. scripts/reload.sh && scripts/test-sites.sh
  4. URLs do projeto (CORS, URL pública, VITE_API_URL...) com https://$host
  5. Tabela de convenções em docs/README.md#convenções
EOF
