#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root
log_info "Iniciando: $(basename "$0")"

# ==============================================================================
# Constantes
# ==============================================================================

readonly SSHD_CONFIG="/etc/ssh/sshd_config"
readonly SSHD_BANNER="/etc/ssh/banner"
readonly SSHD_CONFIG_BACKUP="/etc/ssh/sshd_config.bak"
readonly CONFIGS_DIR="${SCRIPT_DIR}/../configs"
readonly SSHD_CONFIG_TEMPLATE="${CONFIGS_DIR}/sshd_config"
readonly BANNER_TEMPLATE="${CONFIGS_DIR}/ssh_banner.txt"

# ==============================================================================
# Validação de pré-requisitos
# ==============================================================================

if [[ ! -f "${SSHD_CONFIG_TEMPLATE}" ]]; then
    log_error "Template não encontrado: ${SSHD_CONFIG_TEMPLATE}"
    exit 1
fi

if [[ ! -f "${BANNER_TEMPLATE}" ]]; then
    log_error "Banner não encontrado: ${BANNER_TEMPLATE}"
    exit 1
fi

if ! command -v sshd &>/dev/null; then
    log_error "sshd não encontrado. Instale o pacote openssh-server antes de executar este script."
    exit 1
fi

# ==============================================================================
# 1. Backup do sshd_config original (apenas se backup não existir)
# ==============================================================================

if [[ ! -f "${SSHD_CONFIG_BACKUP}" ]]; then
    if [[ -f "${SSHD_CONFIG}" ]]; then
        log_info "Criando backup: ${SSHD_CONFIG_BACKUP}"
        cp --preserve=all "${SSHD_CONFIG}" "${SSHD_CONFIG_BACKUP}"
        chmod 600 "${SSHD_CONFIG_BACKUP}"
        log_info "Backup criado com sucesso"
    else
        log_warn "Arquivo ${SSHD_CONFIG} não encontrado — nenhum backup criado"
    fi
else
    log_info "Backup já existe: ${SSHD_CONFIG_BACKUP} — ignorando"
fi

# ==============================================================================
# 2. Copiar template e substituir variáveis ({{SSH_PORT}})
# ==============================================================================

log_info "Aplicando template: ${SSHD_CONFIG_TEMPLATE}"

# Captura md5sum do arquivo atual antes de modificar (para detecção de mudança)
_md5_antes=""
if [[ -f "${SSHD_CONFIG}" ]]; then
    _md5_antes="$(md5sum "${SSHD_CONFIG}" | awk '{print $1}')"
fi

# Copia o template para um arquivo temporário para substituição segura
_tmpfile="$(mktemp /tmp/sshd_config.XXXXXX)"

# Garante remoção do temporário em qualquer saída
# shellcheck disable=SC2064
trap "rm -f '${_tmpfile}'" EXIT

cp "${SSHD_CONFIG_TEMPLATE}" "${_tmpfile}"

# Substitui o placeholder {{SSH_PORT}} pelo valor da variável (padrão vindo de common.sh)
sed -i "s/{{SSH_PORT}}/${SSH_PORT}/g" "${_tmpfile}"

# Verifica se ainda há placeholders não substituídos (indica template incompleto)
if grep -qE '\{\{[A-Z_]+\}\}' "${_tmpfile}"; then
    log_warn "Placeholders não substituídos encontrados no template:"
    grep -E '\{\{[A-Z_]+\}\}' "${_tmpfile}" | while IFS= read -r linha; do
        log_warn "  ${linha}"
    done
fi

# Instala com permissões corretas
install -m 600 -o root -g root "${_tmpfile}" "${SSHD_CONFIG}"
log_info "sshd_config instalado em: ${SSHD_CONFIG}"

# ==============================================================================
# 3. Copiar banner para /etc/ssh/banner
# ==============================================================================

log_info "Instalando banner SSH: ${SSHD_BANNER}"
install -m 644 -o root -g root "${BANNER_TEMPLATE}" "${SSHD_BANNER}"
log_info "Banner instalado com sucesso"

# ==============================================================================
# 4. Validar configuração com sshd -t — rollback em caso de falha
# ==============================================================================

log_info "Validando configuração SSH com: sshd -t"

# Função de rollback — restaura backup e interrompe execução
_rollback() {
    log_error "Falha na validação do sshd_config — iniciando rollback"
    if [[ -f "${SSHD_CONFIG_BACKUP}" ]]; then
        cp --preserve=all "${SSHD_CONFIG_BACKUP}" "${SSHD_CONFIG}"
        log_warn "Configuração restaurada do backup: ${SSHD_CONFIG_BACKUP}"
    else
        log_error "Backup não disponível — ${SSHD_CONFIG} pode estar em estado inválido!"
    fi
    exit 1
}

if ! sshd -t 2>/dev/null; then
    # Captura saída de erro para log mais detalhado
    _sshd_err="$(sshd -t 2>&1 || true)"
    log_error "sshd -t reportou erro:"
    log_error "${_sshd_err}"
    _rollback
fi

log_info "Validação do sshd_config: OK"

# ==============================================================================
# 5. Restart sshd apenas se a configuração mudou (comparar md5sum)
# ==============================================================================

_md5_depois="$(md5sum "${SSHD_CONFIG}" | awk '{print $1}')"

if [[ "${_md5_antes}" != "${_md5_depois}" ]]; then
    log_info "Configuração modificada — reiniciando sshd"

    # Detecta o gerenciador de serviços disponível
    if systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
        # Tenta reiniciar o serviço correto (nome varia entre distros)
        if systemctl list-units --type=service | grep -q '^.*sshd\.service'; then
            systemctl restart sshd
            log_info "Serviço reiniciado: sshd"
        else
            systemctl restart ssh
            log_info "Serviço reiniciado: ssh"
        fi
    else
        log_warn "sshd não parece estar em execução via systemd — restart ignorado"
        log_warn "Reinicie manualmente: systemctl restart sshd"
    fi
else
    log_info "Configuração sem alterações — restart do sshd ignorado (idempotente)"
fi

# ==============================================================================
# 6. Resumo das restrições aplicadas
# ==============================================================================

log_info "-------------------------------------------------------------------"
log_info "Hardening SSH aplicado com sucesso. Resumo:"
log_info "  Porta SSH           : ${SSH_PORT}"
log_info "  PermitRootLogin     : no"
log_info "  PasswordAuthentication: no"
log_info "  MaxAuthTries        : 3"
log_info "  ClientAliveInterval : 180s"
log_info "  X11Forwarding       : no"
log_info "  AllowTcpForwarding  : no"
log_info "  Banner              : ${SSHD_BANNER}"
log_info "  Config              : ${SSHD_CONFIG}"
log_info "  Backup original     : ${SSHD_CONFIG_BACKUP}"
log_info "-------------------------------------------------------------------"
log_warn "ATENCAO: Certifique-se de que a porta ${SSH_PORT} esta liberada no firewall"
log_warn "         antes de encerrar esta sessao SSH."

log_info "Concluído: $(basename "$0")"
