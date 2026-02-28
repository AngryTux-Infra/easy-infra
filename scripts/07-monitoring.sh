#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root
log_info "Iniciando: $(basename "$0")"

# ==============================================================================
# 1. Instalar pacotes de monitoramento
# ==============================================================================
log_info "Instalando sysstat e logwatch"
ensure_package "sysstat"
ensure_package "logwatch"

# ==============================================================================
# 2. Habilitar coleta de dados do sysstat
# ==============================================================================
SYSSTAT_DEFAULT="/etc/default/sysstat"

if [[ -f "${SYSSTAT_DEFAULT}" ]]; then
    if grep -q '^ENABLED="true"' "${SYSSTAT_DEFAULT}"; then
        log_info "sysstat já habilitado em ${SYSSTAT_DEFAULT}"
    else
        log_info "Habilitando sysstat em ${SYSSTAT_DEFAULT}"
        sed -i 's/^ENABLED=.*/ENABLED="true"/' "${SYSSTAT_DEFAULT}"
        log_info "sysstat habilitado com sucesso"
    fi
else
    log_warn "Arquivo ${SYSSTAT_DEFAULT} não encontrado — pulando configuração do sysstat"
fi

# ==============================================================================
# 3. Configurar coleta sysstat a cada 10 minutos
# ==============================================================================
# O pacote sysstat no Debian/Ubuntu instala /etc/cron.d/sysstat com coleta a
# cada 10 minutos por padrão. Verificamos se já está presente e correto.
SYSSTAT_CRON="/etc/cron.d/sysstat"

if [[ -f "${SYSSTAT_CRON}" ]]; then
    if grep -qE '^\*/10' "${SYSSTAT_CRON}" || grep -qE '^5-55/10' "${SYSSTAT_CRON}"; then
        log_info "Cron do sysstat já configurado com intervalo de 10 minutos"
    else
        log_info "Ajustando cron do sysstat para coleta a cada 10 minutos"
        # Substitui qualquer entrada de coleta (sa1) por intervalo de 10 minutos
        sed -i 's|^[0-9*/,-]* \* \* \* \* .*sa1.*|*/10 * * * * root command -v debian-sa1 > /dev/null \&\& debian-sa1 1 1|' \
            "${SYSSTAT_CRON}"
        log_info "Cron do sysstat atualizado para intervalo de 10 minutos"
    fi
else
    log_info "Criando cron do sysstat em ${SYSSTAT_CRON}"
    cat > "${SYSSTAT_CRON}" <<'EOF'
# /etc/cron.d/sysstat — coleta de estatísticas a cada 10 minutos
PATH=/usr/lib/sysstat:/usr/sbin:/usr/sbin:/usr/bin:/sbin:/bin

*/10 * * * * root command -v debian-sa1 > /dev/null && debian-sa1 1 1

# Gera resumo diário às 23:59
59 23 * * * root command -v debian-sa1 > /dev/null && debian-sa1 60 2
EOF
    log_info "Arquivo de cron do sysstat criado"
fi

# ==============================================================================
# 4. Instalar o script de health-check em /usr/local/bin/server-health
# ==============================================================================
HEALTH_SCRIPT_SRC="${SCRIPT_DIR}/../configs/monitoring/server-health.sh"
HEALTH_SCRIPT_DST="/usr/local/bin/server-health"

if [[ ! -f "${HEALTH_SCRIPT_SRC}" ]]; then
    log_error "Script de health-check não encontrado: ${HEALTH_SCRIPT_SRC}"
    exit 1
fi

# Compara conteúdo para garantir idempotência — só copia se diferente
if [[ -f "${HEALTH_SCRIPT_DST}" ]] && cmp -s "${HEALTH_SCRIPT_SRC}" "${HEALTH_SCRIPT_DST}"; then
    log_info "Health-check script já está atualizado em ${HEALTH_SCRIPT_DST}"
else
    log_info "Instalando health-check script em ${HEALTH_SCRIPT_DST}"
    install -m 0755 "${HEALTH_SCRIPT_SRC}" "${HEALTH_SCRIPT_DST}"
    log_info "Health-check script instalado com sucesso"
fi

# ==============================================================================
# 5. Reiniciar sysstat para aplicar configurações
# ==============================================================================
if systemctl is-enabled --quiet sysstat 2>/dev/null; then
    log_info "sysstat já habilitado via systemd"
else
    if systemctl list-unit-files sysstat.service &>/dev/null; then
        log_info "Habilitando sysstat via systemd"
        systemctl enable sysstat 2>/dev/null || log_warn "Não foi possível habilitar sysstat via systemd"
    fi
fi

log_info "Monitoramento configurado. Execute 'server-health' para verificar o estado do servidor."
log_info "Concluído: $(basename "$0")"
