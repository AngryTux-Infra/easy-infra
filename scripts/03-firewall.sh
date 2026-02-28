#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root
log_info "Iniciando: $(basename "$0")"

# ==============================================================================
# Variável local com default — pode ser sobrescrita via .env ou ambiente
# ==============================================================================

# Portas adicionais a liberar no firewall (separadas por vírgula, ex: "80,443")
ALLOWED_PORTS="${ALLOWED_PORTS:-}"

# ==============================================================================
# 1. Instalar UFW se não presente
# ==============================================================================
ensure_package "ufw"

# ==============================================================================
# 2. Definir política padrão: bloquear entrada, permitir saída
# ==============================================================================
log_info "Definindo políticas padrão do UFW"
ufw default deny incoming
ufw default allow outgoing

# ==============================================================================
# 3. Liberar porta SSH com rate limiting (ANTES de ativar o UFW)
# ==============================================================================
log_info "Liberando porta SSH com rate limiting: ${SSH_PORT}/tcp"
ufw limit "${SSH_PORT}/tcp"

# ==============================================================================
# 4. Liberar portas adicionais via ALLOWED_PORTS (ex: "80,443")
# ==============================================================================
if [[ -n "${ALLOWED_PORTS}" ]]; then
    # Substitui vírgulas por espaços para iterar com for
    IFS=',' read -ra _portas <<< "${ALLOWED_PORTS}"
    for porta in "${_portas[@]}"; do
        # Remove espaços em branco ao redor da porta
        porta="${porta// /}"
        if [[ -n "${porta}" ]]; then
            log_info "Liberando porta adicional: ${porta}"
            ufw allow "${porta}"
        fi
    done
else
    log_info "ALLOWED_PORTS não definido — nenhuma porta adicional liberada"
fi

# ==============================================================================
# 5. Liberar IPs/redes confiáveis via FIREWALL_ALLOWED_IPS
# ==============================================================================
if [[ -n "${FIREWALL_ALLOWED_IPS}" ]]; then
    for ip in ${FIREWALL_ALLOWED_IPS}; do
        log_info "Liberando acesso total para IP/rede: ${ip}"
        ufw allow from "${ip}"
    done
else
    log_info "FIREWALL_ALLOWED_IPS não definido — nenhum IP confiável adicionado"
fi

# ==============================================================================
# 6. Habilitar UFW sem prompt interativo
# ==============================================================================
log_info "Habilitando UFW"
ufw --force enable

# ==============================================================================
# 7. Exibir status do UFW
# ==============================================================================
log_info "Status atual do UFW:"
ufw status verbose

log_info "Concluído: $(basename "$0")"
