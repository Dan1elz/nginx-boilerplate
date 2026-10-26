# Funções comuns dos scripts. Uso: . "$(dirname "$0")/lib.sh"
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Lê o .env (se existir): os scripts usam as mesmas variáveis do compose
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi
CERT_NAME="${CERT_NAME:-example.com}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERRO:\033[0m %s\n' "$*" >&2; exit 1; }

nginx_running() {
    [ -n "$(docker compose ps --status running -q nginx 2>/dev/null)" ]
}

# nginx -t no container em execução; se estiver parado, num container descartável
nginx_test() {
    if nginx_running; then
        docker compose exec -T nginx nginx -t
    else
        docker compose run --rm --no-deps -T nginx nginx -t
    fi
}
