# lib/common.sh — Funções compartilhadas para scripts easy-infra
#
# USO: source "${SCRIPT_DIR}/../lib/common.sh"
#
# IMPORTANTE: Este arquivo é carregado via 'source', NÃO executado diretamente.
# Não possui shebang nem 'set -euo pipefail' — cada script define o seu próprio.

# ==============================================================================
# Cores ANSI com fallback para terminais sem suporte
# ==============================================================================

# Verifica se o terminal suporta cores
_setup_colors() {
    # Habilita cores apenas se stdout for um terminal e a variável TERM estiver definida
    if [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && [[ "${TERM}" != "dumb" ]]; then
        COLOR_RED='\033[0;31m'
        COLOR_GREEN='\033[0;32m'
        COLOR_YELLOW='\033[1;33m'
        COLOR_RESET='\033[0m'
    else
        COLOR_RED=''
        COLOR_GREEN=''
        COLOR_YELLOW=''
        COLOR_RESET=''
    fi
}

_setup_colors

# ==============================================================================
# Funções de logging com timestamp
# ==============================================================================

# Retorna timestamp no formato ISO 8601
_timestamp() {
    date '+%Y-%m-%dT%H:%M:%S'
}

# log_info — mensagem informativa em verde para stdout
log_info() {
    local mensagem="${1:-}"
    printf "${COLOR_GREEN}[INFO]${COLOR_RESET} [%s] %s\n" "$(_timestamp)" "${mensagem}"
}

# log_warn — mensagem de aviso em amarelo para stdout
log_warn() {
    local mensagem="${1:-}"
    printf "${COLOR_YELLOW}[WARN]${COLOR_RESET} [%s] %s\n" "$(_timestamp)" "${mensagem}"
}

# log_error — mensagem de erro em vermelho para stderr
log_error() {
    local mensagem="${1:-}"
    printf "${COLOR_RED}[ERROR]${COLOR_RESET} [%s] %s\n" "$(_timestamp)" "${mensagem}" >&2
}

# ==============================================================================
# Verificação de privilégios
# ==============================================================================

# require_root — encerra com erro se o script não estiver sendo executado como root
require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "Este script precisa ser executado como root (use sudo)."
        log_error "Usuário atual: $(id -un) (UID=${EUID})"
        exit 1
    fi
}

# ==============================================================================
# Gerenciamento de pacotes (idempotente)
# ==============================================================================

# is_installed — verifica se um pacote está instalado via dpkg
# Retorna 0 se instalado, 1 caso contrário
# Uso: if is_installed "nginx"; then ...
is_installed() {
    local pacote="${1:?'is_installed requer o nome do pacote como argumento'}"
    dpkg-query -W -f='${Status}' "${pacote}" 2>/dev/null | grep -q '^install ok installed'
}

# ensure_package — instala um pacote apenas se ainda não estiver instalado
# Garante idempotência: executa apt-get install somente quando necessário
# Uso: ensure_package "curl"
ensure_package() {
    local pacote="${1:?'ensure_package requer o nome do pacote como argumento'}"

    if is_installed "${pacote}"; then
        log_info "Pacote já instalado: ${pacote}"
        return 0
    fi

    log_info "Instalando pacote: ${pacote}"
    apt-get install -y "${pacote}"
    log_info "Pacote instalado com sucesso: ${pacote}"
}

# ==============================================================================
# Carregamento de variáveis de ambiente
# ==============================================================================

# Determina a raiz do projeto subindo até encontrar lib/common.sh
# Isso permite que scripts em qualquer subdiretório encontrem o .env corretamente
_encontrar_raiz_projeto() {
    local dir
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Sobe no máximo 5 níveis em busca da raiz (onde existe o diretório lib/)
    local nivel=0
    while [[ "${nivel}" -lt 5 ]]; do
        if [[ -d "${dir}/lib" ]]; then
            echo "${dir}"
            return 0
        fi
        dir="$(dirname "${dir}")"
        nivel=$((nivel + 1))
    done

    # Fallback: assume que common.sh está em <raiz>/lib/
    local fallback
    fallback="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    echo "${fallback}"
}

# Raiz do projeto — usada para localizar o arquivo .env
PROJETO_ROOT="$(_encontrar_raiz_projeto)"

# Carrega o arquivo .env da raiz do projeto, se existir
if [[ -f "${PROJETO_ROOT}/.env" ]]; then
    # shellcheck source=/dev/null
    source "${PROJETO_ROOT}/.env"
    log_info "Configurações carregadas de: ${PROJETO_ROOT}/.env"
fi

# ==============================================================================
# Variáveis de configuração com valores padrão
# Podem ser sobrescritas via .env ou variáveis de ambiente do sistema
# ==============================================================================

# Porta SSH (padrão diferente do 22 por segurança)
SSH_PORT="${SSH_PORT:-2222}"

# Fuso horário do servidor
SERVER_TIMEZONE="${SERVER_TIMEZONE:-UTC}"

# Nome do usuário administrador a ser criado
ADMIN_USER="${ADMIN_USER:-sysadmin}"

# Diretório home do usuário administrador
ADMIN_HOME="${ADMIN_HOME:-/home/${ADMIN_USER}}"

# Grupos adicionais para o usuário administrador (separados por vírgula)
ADMIN_GROUPS="${ADMIN_GROUPS:-sudo,adm}"

# Chave pública SSH para o usuário administrador (opcional)
ADMIN_SSH_KEY="${ADMIN_SSH_KEY:-}"

# Habilitar autenticação por senha no SSH (yes/no)
SSH_PASSWORD_AUTH="${SSH_PASSWORD_AUTH:-no}"

# Habilitar login direto do root via SSH (yes/no)
SSH_PERMIT_ROOT_LOGIN="${SSH_PERMIT_ROOT_LOGIN:-no}"

# Nome do servidor (hostname)
SERVER_HOSTNAME="${SERVER_HOSTNAME:-}"

# Diretório de logs da aplicação
LOG_DIR="${LOG_DIR:-/var/log/easy-infra}"

# Versão do repositório APT para pacotes adicionais (ex: bookworm, jammy)
APT_RELEASE="${APT_RELEASE:-}"

# Habilitar atualizações automáticas de segurança (true/false)
AUTO_SECURITY_UPDATES="${AUTO_SECURITY_UPDATES:-true}"

# Endereços IP ou redes permitidos no firewall (separados por espaço)
# Exemplo: "192.168.1.0/24 10.0.0.1"
FIREWALL_ALLOWED_IPS="${FIREWALL_ALLOWED_IPS:-}"
