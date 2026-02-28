#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root
log_info "Iniciando: $(basename "$0")"

# ==============================================================================
# Constantes
# ==============================================================================

readonly F2B_JAIL_DEST="/etc/fail2ban/jail.local"
readonly F2B_JAIL_TEMPLATE="${SCRIPT_DIR}/../configs/fail2ban/jail.local"

# ==============================================================================
# Variáveis locais com defaults — podem ser sobrescritas via .env ou ambiente
# ==============================================================================

# Duração do ban em segundos (padrão: 1 hora)
F2B_BANTIME="${F2B_BANTIME:-3600}"

# Janela de tempo para contagem de falhas em segundos (padrão: 10 minutos)
F2B_FINDTIME="${F2B_FINDTIME:-600}"

# Número máximo de tentativas antes do ban (padrão: 5)
F2B_MAXRETRY="${F2B_MAXRETRY:-5}"

# ==============================================================================
# Validação de pré-requisitos
# ==============================================================================

if [[ ! -f "${F2B_JAIL_TEMPLATE}" ]]; then
    log_error "Template não encontrado: ${F2B_JAIL_TEMPLATE}"
    exit 1
fi

# ==============================================================================
# 1. Instalar fail2ban (idempotente via ensure_package)
# ==============================================================================

log_info "Verificando instalação do fail2ban"
ensure_package "fail2ban"

# ==============================================================================
# 2. Gerar jail.local a partir do template com substituição de placeholders
# ==============================================================================

log_info "Gerando configuração a partir do template: ${F2B_JAIL_TEMPLATE}"

# Arquivo temporário para substituição segura
_tmpfile="$(mktemp /tmp/jail.local.XXXXXX)"

# Garante remoção do temporário em qualquer saída
# shellcheck disable=SC2064
trap "rm -f '${_tmpfile}'" EXIT

cp "${F2B_JAIL_TEMPLATE}" "${_tmpfile}"

# Substitui todos os placeholders no arquivo temporário
sed -i "s/{{SSH_PORT}}/${SSH_PORT}/g"       "${_tmpfile}"
sed -i "s/{{F2B_BANTIME}}/${F2B_BANTIME}/g"   "${_tmpfile}"
sed -i "s/{{F2B_FINDTIME}}/${F2B_FINDTIME}/g" "${_tmpfile}"
sed -i "s/{{F2B_MAXRETRY}}/${F2B_MAXRETRY}/g" "${_tmpfile}"

# Avisa sobre placeholders eventualmente não substituídos (template desatualizado)
if grep -qE '\{\{[A-Z_]+\}\}' "${_tmpfile}"; then
    log_warn "Placeholders não substituídos encontrados no template:"
    grep -E '\{\{[A-Z_]+\}\}' "${_tmpfile}" | while IFS= read -r _linha; do
        log_warn "  ${_linha}"
    done
fi

# ==============================================================================
# 3. Instalar jail.local apenas se o conteúdo for diferente (idempotente)
# ==============================================================================

_instalar_config=true

if [[ -f "${F2B_JAIL_DEST}" ]]; then
    _md5_existente="$(md5sum "${F2B_JAIL_DEST}" | awk '{print $1}')"
    _md5_novo="$(md5sum "${_tmpfile}" | awk '{print $1}')"

    if [[ "${_md5_existente}" == "${_md5_novo}" ]]; then
        log_info "Conteúdo de ${F2B_JAIL_DEST} não mudou — instalação ignorada (idempotente)"
        _instalar_config=false
    else
        log_info "Conteúdo diferente detectado — atualizando ${F2B_JAIL_DEST}"
    fi
else
    log_info "Arquivo não existe — instalando pela primeira vez: ${F2B_JAIL_DEST}"
fi

if [[ "${_instalar_config}" == "true" ]]; then
    install -m 644 -o root -g root "${_tmpfile}" "${F2B_JAIL_DEST}"
    log_info "Configuração instalada em: ${F2B_JAIL_DEST}"
fi

# ==============================================================================
# 4. Habilitar e iniciar o serviço fail2ban
# ==============================================================================

log_info "Habilitando serviço fail2ban no boot"
systemctl enable fail2ban

log_info "Iniciando/reiniciando serviço fail2ban"
if systemctl is-active --quiet fail2ban; then
    # Recarrega a configuração sem derrubar o serviço quando já estava rodando
    systemctl reload-or-restart fail2ban
    log_info "Serviço fail2ban recarregado"
else
    systemctl start fail2ban
    log_info "Serviço fail2ban iniciado"
fi

# ==============================================================================
# 5. Aguardar inicialização e exibir status dos jails ativos
# ==============================================================================

log_info "Aguardando fail2ban carregar os jails..."

# Tenta até 10 vezes com intervalo de 1 segundo (máximo 10s de espera)
_tentativas=0
until fail2ban-client ping &>/dev/null || [[ "${_tentativas}" -ge 10 ]]; do
    _tentativas=$((_tentativas + 1))
    sleep 1
done

if fail2ban-client ping &>/dev/null; then
    log_info "Status dos jails ativos:"
    fail2ban-client status
else
    log_warn "fail2ban-client não respondeu a tempo — verifique com: fail2ban-client status"
fi

# ==============================================================================
# Resumo
# ==============================================================================

log_info "-------------------------------------------------------------------"
log_info "Fail2ban configurado com sucesso. Resumo:"
log_info "  Config             : ${F2B_JAIL_DEST}"
log_info "  Porta SSH (sshd)   : ${SSH_PORT}"
log_info "  bantime            : ${F2B_BANTIME}s"
log_info "  findtime           : ${F2B_FINDTIME}s"
log_info "  maxretry           : ${F2B_MAXRETRY}"
log_info "  Ban reincidentes   : 604800s (1 semana)"
log_info "-------------------------------------------------------------------"

log_info "Concluído: $(basename "$0")"
