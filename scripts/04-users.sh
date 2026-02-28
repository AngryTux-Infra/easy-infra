#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
require_root
log_info "Iniciando: $(basename "$0")"

# ==============================================================================
# Variáveis derivadas
# ==============================================================================
ADMIN_SSH_DIR="${ADMIN_HOME}/.ssh"
ADMIN_AUTH_KEYS="${ADMIN_SSH_DIR}/authorized_keys"
ROOT_AUTH_KEYS="/root/.ssh/authorized_keys"
SUDOERS_SRC="${SCRIPT_DIR}/../configs/sudoers.d/admin-nopasswd"
SUDOERS_DEST="/etc/sudoers.d/admin-nopasswd"

# ==============================================================================
# 1. Criar usuário ${ADMIN_USER} se não existir
# ==============================================================================
if id "${ADMIN_USER}" &>/dev/null; then
    log_info "Usuário já existe: ${ADMIN_USER}"
else
    log_info "Criando usuário: ${ADMIN_USER}"
    useradd \
        --create-home \
        --home-dir "${ADMIN_HOME}" \
        --shell /bin/bash \
        --comment "Admin user managed by easy-infra" \
        "${ADMIN_USER}"
    log_info "Usuário criado: ${ADMIN_USER}"
fi

# ==============================================================================
# 2. Garantir shell /bin/bash
# ==============================================================================
current_shell="$(getent passwd "${ADMIN_USER}" | cut -d: -f7)"
if [[ "${current_shell}" != "/bin/bash" ]]; then
    log_info "Definindo shell /bin/bash para: ${ADMIN_USER}"
    usermod --shell /bin/bash "${ADMIN_USER}"
else
    log_info "Shell já configurado como /bin/bash para: ${ADMIN_USER}"
fi

# ==============================================================================
# 3. Adicionar aos grupos (ADMIN_GROUPS — separados por vírgula)
# ==============================================================================
IFS=',' read -ra _grupos <<< "${ADMIN_GROUPS}"
for _grupo in "${_grupos[@]}"; do
    _grupo="${_grupo// /}"  # remove espaços acidentais
    if getent group "${_grupo}" &>/dev/null; then
        if id -nG "${ADMIN_USER}" | tr ' ' '\n' | grep -qx "${_grupo}"; then
            log_info "Usuário ${ADMIN_USER} já pertence ao grupo: ${_grupo}"
        else
            log_info "Adicionando ${ADMIN_USER} ao grupo: ${_grupo}"
            usermod -aG "${_grupo}" "${ADMIN_USER}"
        fi
    else
        log_warn "Grupo não encontrado, pulando: ${_grupo}"
    fi
done

# ==============================================================================
# 4. Preparar diretório .ssh do usuário admin
# ==============================================================================
if [[ ! -d "${ADMIN_SSH_DIR}" ]]; then
    log_info "Criando diretório .ssh: ${ADMIN_SSH_DIR}"
    mkdir -p "${ADMIN_SSH_DIR}"
fi

# ==============================================================================
# 5. Copiar authorized_keys do root (se existirem) — não falha se ausente
# ==============================================================================
if [[ -f "${ROOT_AUTH_KEYS}" ]]; then
    if [[ ! -f "${ADMIN_AUTH_KEYS}" ]]; then
        log_info "Copiando authorized_keys do root para: ${ADMIN_USER}"
        cp "${ROOT_AUTH_KEYS}" "${ADMIN_AUTH_KEYS}"
    else
        log_info "authorized_keys já existe para: ${ADMIN_USER} — mesclando chaves do root"
        # Adiciona apenas chaves que ainda não estão presentes
        while IFS= read -r _linha; do
            if [[ -n "${_linha}" ]] && ! grep -qxF "${_linha}" "${ADMIN_AUTH_KEYS}"; then
                printf '%s\n' "${_linha}" >> "${ADMIN_AUTH_KEYS}"
            fi
        done < "${ROOT_AUTH_KEYS}"
    fi
else
    log_warn "authorized_keys do root não encontrado em ${ROOT_AUTH_KEYS} — nenhuma chave copiada"
fi

# ==============================================================================
# 6. Adicionar ADMIN_SSH_KEY ao authorized_keys (se definida)
# ==============================================================================
if [[ -n "${ADMIN_SSH_KEY:-}" ]]; then
    if [[ ! -f "${ADMIN_AUTH_KEYS}" ]] || ! grep -qxF "${ADMIN_SSH_KEY}" "${ADMIN_AUTH_KEYS}"; then
        log_info "Adicionando ADMIN_SSH_KEY ao authorized_keys de: ${ADMIN_USER}"
        printf '%s\n' "${ADMIN_SSH_KEY}" >> "${ADMIN_AUTH_KEYS}"
    else
        log_info "ADMIN_SSH_KEY já presente no authorized_keys de: ${ADMIN_USER}"
    fi
else
    log_info "ADMIN_SSH_KEY não definida — nenhuma chave adicional inserida"
fi

# ==============================================================================
# 7. Corrigir permissões no .ssh/
# ==============================================================================
log_info "Ajustando permissões em: ${ADMIN_SSH_DIR}"
chmod 700 "${ADMIN_SSH_DIR}"
if [[ -f "${ADMIN_AUTH_KEYS}" ]]; then
    chmod 600 "${ADMIN_AUTH_KEYS}"
fi
chown -R "${ADMIN_USER}:${ADMIN_USER}" "${ADMIN_SSH_DIR}"

# ==============================================================================
# 8. Instalar configuração sudoers (validar com visudo antes de copiar)
# ==============================================================================
if [[ ! -f "${SUDOERS_SRC}" ]]; then
    log_error "Arquivo sudoers de origem não encontrado: ${SUDOERS_SRC}"
    exit 1
fi

if [[ -f "${SUDOERS_DEST}" ]]; then
    if diff -q "${SUDOERS_SRC}" "${SUDOERS_DEST}" &>/dev/null; then
        log_info "Configuração sudoers já instalada e atualizada: ${SUDOERS_DEST}"
    else
        log_info "Atualizando configuração sudoers: ${SUDOERS_DEST}"
        if visudo -cf "${SUDOERS_SRC}"; then
            cp "${SUDOERS_SRC}" "${SUDOERS_DEST}"
            chmod 440 "${SUDOERS_DEST}"
            log_info "Sudoers atualizado com sucesso: ${SUDOERS_DEST}"
        else
            log_error "Validação visudo falhou para: ${SUDOERS_SRC}"
            exit 1
        fi
    fi
else
    log_info "Instalando configuração sudoers: ${SUDOERS_DEST}"
    if visudo -cf "${SUDOERS_SRC}"; then
        cp "${SUDOERS_SRC}" "${SUDOERS_DEST}"
        chmod 440 "${SUDOERS_DEST}"
        log_info "Sudoers instalado com sucesso: ${SUDOERS_DEST}"
    else
        log_error "Validação visudo falhou para: ${SUDOERS_SRC}"
        exit 1
    fi
fi

log_info "Concluído: $(basename "$0")"
