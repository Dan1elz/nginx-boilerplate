#!/bin/sh
# Sobe o vigia do certificado em segundo plano; a saída vai para o log do container.
cert-watch &
echo "$0: cert-watch iniciado (confere a cada ${CERT_WATCH_INTERVAL:-300}s)"
