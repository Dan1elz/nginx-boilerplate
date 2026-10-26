#!/bin/sh
# Valida a config (nginx -t). Rode SEMPRE antes de recarregar.
. "$(dirname "$0")/lib.sh"
nginx_test
