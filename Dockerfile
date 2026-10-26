# nginx oficial + o mínimo para operar sozinho:
# - openssl: gera um certificado provisório enquanto o Let's Encrypt não existe
# - scripts que escolhem o certificado e recarregam quando ele é renovado
# A config (nginx.conf, sites, snippets) NÃO entra na imagem: vem por volume,
# então mudar um site é só editar e recarregar, sem rebuild.
ARG NGINX_VERSION=1.30.6
FROM nginx:${NGINX_VERSION}-alpine

RUN apk add --no-cache openssl

# Roda antes do nginx subir (o entrypoint da imagem executa /docker-entrypoint.d/*.sh em ordem)
COPY docker/40-ssl-cert.sh /docker-entrypoint.d/40-ssl-cert.sh
COPY docker/50-cert-watch.sh /docker-entrypoint.d/50-cert-watch.sh
COPY docker/select-cert.sh /usr/local/bin/select-cert
COPY docker/cert-watch.sh /usr/local/bin/cert-watch
RUN chmod +x /docker-entrypoint.d/40-ssl-cert.sh /docker-entrypoint.d/50-cert-watch.sh \
    /usr/local/bin/select-cert /usr/local/bin/cert-watch \
    # Os scripts padrão da imagem mexem no default.conf, que não usamos
    && rm -f /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh \
             /docker-entrypoint.d/20-envsubst-on-templates.sh
