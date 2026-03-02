# Community Tooling Plan (Small Team)

## Stack alvo (small team)

- **Semaphore (UI web via container)** para execução centralizada de playbooks.
- **ARA** para trilha de auditoria e relatórios detalhados de execução.
- **Molecule** para testes de role em container (padrão da comunidade).
- **KICS** para análise estática de segurança em IaC (incluindo Ansible).
- **ansible-lint + yamllint** para qualidade de código YAML/playbook.

## O que já está pronto no repositório

- ARA integrado e documentado.
- Testes de integração em container Debian 13 via Docker Compose.
- Lint e testes unitários em funcionamento.

## Ferramenta comunitária para testes em container (igual ao cenário atual)

Sim: **Molecule**.

- Suporta drivers `docker` e `podman`.
- Executa ciclo de teste completo de roles: `create`, `converge`, `verify`, `destroy`.
- É o caminho mais comum na comunidade para substituir scripts custom de integração.

## AWX: o que melhora (e por que deixar documentado)

AWX melhora principalmente quando o time cresce ou a governança fica mais exigente:

- RBAC avançado por time/projeto/inventário/credenciais.
- Workflows visuais entre jobs.
- Gestão centralizada de credenciais e inventários.
- Auditoria operacional e histórico com mais controle de acesso.
- Escalabilidade e padronização para múltiplos ambientes/timezones.

## Quando migrar de Semaphore para AWX

Considere migração quando houver:

- necessidade forte de segregação de acesso por equipes,
- muitos workflows interdependentes,
- demanda de compliance/auditoria formal,
- crescimento de ambientes e operadores simultâneos.

## Pendência futura: segurança contínua containerizada

Objetivo: manter o hardening atual no host e adicionar uma esteira separada de varredura e alerta, sem acoplamento ao playbook principal.

- Scanner em container (prioridade inicial): **Trivy**.
- Observabilidade e alerta: **Prometheus + Grafana + Alertmanager**.
- Execução: `docker compose` com agendamento diário (cron/systemd timer no host).
- Evidências: exportar relatório JSON em volume persistente e histórico mínimo de 30 dias.
- Métricas mínimas:
  - timestamp do último scan com sucesso,
  - total de CVEs `critical`,
  - total de CVEs `high`.
- Política de alerta inicial:
  - `critical > 0` -> alerta imediato,
  - scan sem sucesso por mais de 24h -> alerta operacional.

Observação: manter este bloco como fase 2. O estado atual (hardening + backup + anti-lockout + playbook idempotente) segue como baseline de produção do homelab.
