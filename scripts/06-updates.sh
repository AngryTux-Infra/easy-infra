#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root
log_info "Iniciando: $(basename "$0")"

# ==============================================================================
# Variáveis locais com defaults — podem ser sobrescritas via .env ou ambiente
# ==============================================================================

# Reinicialização automática após atualizações (true/false)
AUTO_REBOOT="${AUTO_REBOOT:-false}"

# E-mail para notificações de atualização (vazio = desabilitado)
NOTIFY_EMAIL="${NOTIFY_EMAIL:-}"

# Diretório de destino das configurações do apt
APT_CONF_DIR="/etc/apt/apt.conf.d"

# Diretório de origem das configurações do projeto
CONFIGS_SRC="${SCRIPT_DIR}/../configs/unattended-upgrades"

# ==============================================================================
# 1. Instalar unattended-upgrades
# ==============================================================================
ensure_package "unattended-upgrades"
ensure_package "apt-listchanges"

# ==============================================================================
# 2. Copiar e processar arquivos de configuração
# ==============================================================================
log_info "Copiando configurações de unattended-upgrades para ${APT_CONF_DIR}"

for config_file in "${CONFIGS_SRC}"/[0-9]*; do
    dest_name="$(basename "${config_file}")"
    dest_path="${APT_CONF_DIR}/${dest_name}"

    log_info "Processando arquivo de configuração: ${dest_name}"

    # Lê o conteúdo e substitui os placeholders
    config_content="$(cat "${config_file}")"

    # Substitui {{AUTO_REBOOT}} pelo valor da variável
    config_content="${config_content//\{\{AUTO_REBOOT\}\}/${AUTO_REBOOT}}"

    # Substitui {{NOTIFY_EMAIL}} pelo valor da variável
    config_content="${config_content//\{\{NOTIFY_EMAIL\}\}/${NOTIFY_EMAIL}}"

    # Verifica idempotência: só sobrescreve se o conteúdo mudou
    if [[ -f "${dest_path}" ]] && [[ "$(cat "${dest_path}")" == "${config_content}" ]]; then
        log_info "Arquivo já atualizado, sem alterações: ${dest_name}"
    else
        printf '%s\n' "${config_content}" > "${dest_path}"
        chmod 644 "${dest_path}"
        log_info "Arquivo instalado: ${dest_path}"
    fi
done

# ==============================================================================
# 3. Validar configuração gerada
# ==============================================================================
log_info "Validando configuração do unattended-upgrades"

if ! grep -q 'security' "${APT_CONF_DIR}/50unattended-upgrades" 2>/dev/null; then
    log_error "Configuração de security updates não encontrada em 50unattended-upgrades"
    exit 1
fi

if ! grep -q 'Unattended-Upgrade "1"' "${APT_CONF_DIR}/20auto-upgrades" 2>/dev/null; then
    log_error "Configuração de ativação não encontrada em 20auto-upgrades"
    exit 1
fi

log_info "Configuração de AUTO_REBOOT: ${AUTO_REBOOT}"

if [[ -n "${NOTIFY_EMAIL}" ]]; then
    log_info "Notificações por e-mail configuradas para: ${NOTIFY_EMAIL}"
else
    log_info "Notificações por e-mail desabilitadas (NOTIFY_EMAIL não definido)"
fi

# ==============================================================================
# 4. Testar configuração com dry-run
# ==============================================================================
log_info "Executando teste de configuração (dry-run)"

if unattended-upgrades --dry-run --debug 2>&1 | grep -i 'error' | grep -v 'No error'; then
    log_warn "Possíveis erros encontrados no dry-run — verifique a saída acima"
else
    log_info "Dry-run concluído sem erros críticos"
fi

log_info "Concluído: $(basename "$0")"
