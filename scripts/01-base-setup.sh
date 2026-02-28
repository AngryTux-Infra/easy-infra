#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root
log_info "Iniciando: $(basename "$0")"

# ==============================================================================
# 1. Configurar hostname (skip se SERVER_HOSTNAME estiver vazio)
# ==============================================================================
if [[ -n "${SERVER_HOSTNAME:-}" ]]; then
    current_hostname="$(hostname)"
    if [[ "${current_hostname}" != "${SERVER_HOSTNAME}" ]]; then
        log_info "Configurando hostname: ${SERVER_HOSTNAME}"
        hostnamectl set-hostname "${SERVER_HOSTNAME}"
    else
        log_info "Hostname já configurado: ${SERVER_HOSTNAME}"
    fi
else
    log_info "SERVER_HOSTNAME não definido — hostname não alterado"
fi

# ==============================================================================
# 2. Configurar timezone (default: UTC via common.sh)
# ==============================================================================
current_tz="$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo '')"
if [[ "${current_tz}" != "${SERVER_TIMEZONE}" ]]; then
    log_info "Configurando timezone: ${SERVER_TIMEZONE}"
    timedatectl set-timezone "${SERVER_TIMEZONE}"
else
    log_info "Timezone já configurado: ${SERVER_TIMEZONE}"
fi

# ==============================================================================
# 3. Configurar locale en_US.UTF-8
# ==============================================================================
log_info "Configurando locale en_US.UTF-8"
ensure_package "locales"

if ! locale -a 2>/dev/null | grep -q '^en_US\.utf8$'; then
    log_info "Gerando locale en_US.UTF-8"
    sed -i 's/^# \(en_US\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    locale-gen en_US.UTF-8
else
    log_info "Locale en_US.UTF-8 já gerado"
fi

update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ==============================================================================
# 4. Instalar e habilitar NTP via systemd-timesyncd
# ==============================================================================
log_info "Configurando sincronização de tempo via systemd-timesyncd"
ensure_package "systemd-timesyncd"

if ! systemctl is-enabled --quiet systemd-timesyncd 2>/dev/null; then
    log_info "Habilitando systemd-timesyncd"
    systemctl enable systemd-timesyncd
else
    log_info "systemd-timesyncd já habilitado"
fi

if ! systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
    log_info "Iniciando systemd-timesyncd"
    systemctl start systemd-timesyncd
else
    log_info "systemd-timesyncd já em execução"
fi

timedatectl set-ntp true

# ==============================================================================
# 5. Atualizar apt cache e fazer upgrade de pacotes existentes
# ==============================================================================
log_info "Atualizando cache do apt"
apt-get update -q

log_info "Atualizando pacotes existentes"
apt-get upgrade -y -q

# ==============================================================================
# 6. Instalar pacotes essenciais
# ==============================================================================
log_info "Instalando pacotes essenciais"
essential_packages=(
    curl
    wget
    vim
    htop
    net-tools
    unzip
    git
    jq
)

for pkg in "${essential_packages[@]}"; do
    ensure_package "${pkg}"
done

# ==============================================================================
# 7. Criar diretório de logs se não existir
# ==============================================================================
if [[ ! -d "${LOG_DIR}" ]]; then
    log_info "Criando diretório de logs: ${LOG_DIR}"
    mkdir -p "${LOG_DIR}"
    chmod 750 "${LOG_DIR}"
else
    log_info "Diretório de logs já existe: ${LOG_DIR}"
fi

log_info "Concluído: $(basename "$0")"
