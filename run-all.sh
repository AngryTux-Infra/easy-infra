#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
require_root

# ==============================================================================
# run-all.sh — Orquestrador principal do easy-infra
#
# Uso:
#   ./run-all.sh                    # Executa todos os scripts (01–07)
#   ./run-all.sh 01 03 05           # Executa apenas os scripts indicados
#   ./run-all.sh --dry-run          # Lista scripts sem executar
#   ./run-all.sh --dry-run 01 03    # Lista apenas os scripts indicados
# ==============================================================================

# ------------------------------------------------------------------------------
# Constantes
# ------------------------------------------------------------------------------
readonly SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# Todos os scripts disponíveis, em ordem numérica
ALL_SCRIPTS=(
    "01-base-setup.sh"
    "02-ssh-hardening.sh"
    "03-firewall.sh"
    "04-users.sh"
    "05-fail2ban.sh"
    "06-updates.sh"
    "07-monitoring.sh"
)

# ------------------------------------------------------------------------------
# Verificação do arquivo .env
# ------------------------------------------------------------------------------
_verificar_env() {
    if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
        log_warn "Arquivo .env não encontrado na raiz do projeto."
        if [[ -f "${SCRIPT_DIR}/.env.example" ]]; then
            log_warn "Copie o arquivo de exemplo e ajuste as variáveis:"
            log_warn "  cp ${SCRIPT_DIR}/.env.example ${SCRIPT_DIR}/.env"
        else
            log_warn "Crie o arquivo ${SCRIPT_DIR}/.env com as variáveis necessárias."
        fi
        log_warn "Continuando com os valores padrão definidos em lib/common.sh..."
    fi
}

# ------------------------------------------------------------------------------
# Parsing de argumentos
# ------------------------------------------------------------------------------
DRY_RUN=false
PREFIXOS_SOLICITADOS=()

_parse_args() {
    for arg in "$@"; do
        case "${arg}" in
            --dry-run)
                DRY_RUN=true
                ;;
            [0-9][0-9])
                PREFIXOS_SOLICITADOS+=("${arg}")
                ;;
            *)
                log_error "Argumento inválido: '${arg}'"
                log_error "Uso: $(basename "$0") [--dry-run] [01] [02] ... [07]"
                exit 1
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Seleção de scripts a executar
# ------------------------------------------------------------------------------
_selecionar_scripts() {
    local -n _resultado=$1  # nameref para o array de saída

    if [[ "${#PREFIXOS_SOLICITADOS[@]}" -eq 0 ]]; then
        # Nenhum filtro: usar todos os scripts
        _resultado=("${ALL_SCRIPTS[@]}")
        return
    fi

    local script prefixo solicitado encontrado
    for solicitado in "${PREFIXOS_SOLICITADOS[@]}"; do
        encontrado=false
        for script in "${ALL_SCRIPTS[@]}"; do
            prefixo="${script:0:2}"
            if [[ "${prefixo}" == "${solicitado}" ]]; then
                _resultado+=("${script}")
                encontrado=true
                break
            fi
        done
        if [[ "${encontrado}" == false ]]; then
            log_error "Nenhum script encontrado com prefixo '${solicitado}'."
            exit 1
        fi
    done
}

# ------------------------------------------------------------------------------
# Exibição do resumo final
# ------------------------------------------------------------------------------
_exibir_resumo() {
    local -n _scripts=$1
    local -n _status=$2
    local -n _duracoes=$3
    local tempo_total=$4

    local largura_nome=25
    local largura_status=10
    local largura_tempo=12

    printf "\n"
    printf "%-*s %-*s %-*s\n" \
        "${largura_nome}" "SCRIPT" \
        "${largura_status}" "STATUS" \
        "${largura_tempo}" "DURACAO (s)"
    printf '%s\n' "$(printf '%0.s-' {1..50})"

    local i script st dur
    for i in "${!_scripts[@]}"; do
        script="${_scripts[${i}]}"
        st="${_status[${i}]}"
        dur="${_duracoes[${i}]}"

        if [[ "${st}" == "OK" ]]; then
            printf "%-*s ${COLOR_GREEN}%-*s${COLOR_RESET} %-*s\n" \
                "${largura_nome}" "${script}" \
                "${largura_status}" "${st}" \
                "${largura_tempo}" "${dur}"
        else
            printf "%-*s ${COLOR_RED}%-*s${COLOR_RESET} %-*s\n" \
                "${largura_nome}" "${script}" \
                "${largura_status}" "${st}" \
                "${largura_tempo}" "${dur}"
        fi
    done

    printf '%s\n' "$(printf '%0.s-' {1..50})"
    printf "Tempo total de execucao: %s segundos\n\n" "${tempo_total}"
}

# ------------------------------------------------------------------------------
# Execução principal
# ------------------------------------------------------------------------------
main() {
    _parse_args "$@"
    _verificar_env

    local scripts_selecionados=()
    _selecionar_scripts scripts_selecionados

    if [[ "${#scripts_selecionados[@]}" -eq 0 ]]; then
        log_error "Nenhum script selecionado para execução."
        exit 1
    fi

    # --- Modo dry-run ---
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "Modo --dry-run ativado. Scripts que seriam executados:"
        local script
        for script in "${scripts_selecionados[@]}"; do
            printf "  -> %s/%s\n" "${SCRIPTS_DIR}" "${script}"
        done
        exit 0
    fi

    # --- Execução real ---
    local status_scripts=()
    local duracoes=()
    local tempo_inicio_total=${SECONDS}
    local ts_inicio ts_fim duracao_script exit_code

    local script
    for script in "${scripts_selecionados[@]}"; do
        local caminho="${SCRIPTS_DIR}/${script}"

        if [[ ! -f "${caminho}" ]]; then
            log_error "Script não encontrado: ${caminho}"
            status_scripts+=("FALHOU")
            duracoes+=("0")
            # set -e está ativo; forçamos saída após registro
            _exibir_resumo scripts_selecionados status_scripts duracoes $((SECONDS - tempo_inicio_total))
            exit 1
        fi

        ts_inicio=$(_timestamp)
        log_info "Iniciando script: ${script} [${ts_inicio}]"

        local inicio_script=${SECONDS}
        exit_code=0
        bash "${caminho}" || exit_code=$?
        ts_fim=$(_timestamp)
        duracao_script=$((SECONDS - inicio_script))

        if [[ "${exit_code}" -ne 0 ]]; then
            log_error "Script falhou: ${script} [${ts_fim}] (código de saída: ${exit_code})"
            status_scripts+=("FALHOU")
            duracoes+=("${duracao_script}")
            _exibir_resumo scripts_selecionados status_scripts duracoes $((SECONDS - tempo_inicio_total))
            exit "${exit_code}"
        fi

        log_info "Script concluído: ${script} [${ts_fim}] (duração: ${duracao_script}s)"
        status_scripts+=("OK")
        duracoes+=("${duracao_script}")
    done

    _exibir_resumo scripts_selecionados status_scripts duracoes $((SECONDS - tempo_inicio_total))
    log_info "Todos os scripts foram executados com sucesso."
}

main "$@"
