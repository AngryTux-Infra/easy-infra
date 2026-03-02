# easy-infra

Automação de setup inicial de servidores Linux (Debian/Ubuntu) com Ansible — replicável para N servidores, idempotente, configurável por host/grupo.

## O que faz

Aplica um baseline de segurança e configuração em qualquer número de servidores:

```bash
# Setup completo em todos os servidores
ansible-playbook site.yml

# Apenas SSH e firewall
ansible-playbook site.yml --tags ssh,firewall

# Dry-run — mostra o que mudaria sem executar
ansible-playbook site.yml --check --diff

# Servidor específico
ansible-playbook site.yml --limit web01
```

## O que é configurado

| Role | O que faz | Tag |
|------|-----------|-----|
| `etckeeper` | Versionamento do `/etc` com git — audit trail de configs | `etckeeper` |
| `base` | Hostname, timezone, locale, NTP, swap, pacotes essenciais | `base` |
| `debloat` | Remove pacotes e serviços desnecessários (bluetooth, cups, avahi) | `debloat` |
| `ssh` | Hardening SSH — key-only, porta customizável, criptografia moderna, transição de porta segura | `ssh` |
| `firewall` | UFW deny-by-default, rate limiting SSH, limpeza de regras legadas, portas/IPs configuráveis | `firewall` |
| `users` | Usuário admin, sudo sem senha, authorized_keys, root locked | `users` |
| `fail2ban` | Proteção brute-force SSH + jail recidive (ban progressivo, 1 semana) | `fail2ban` |
| `auditd` | Auditoria do sistema — regras para SSH, sudo e alterações em /etc | `auditd` |
| `updates` | unattended-upgrades para security patches automáticos | `updates` |
| `monitoring` | sysstat, logwatch, comando `server-health` com fallback journalctl | `monitoring` |

Ordem de execução: etckeeper → base → debloat → ssh → firewall → users → fail2ban → auditd → updates → monitoring

## Quick start

```bash
git clone https://github.com/AngryTux-Infra/easy-infra.git
cd easy-infra

# Configure o inventário
vim inventories/production/hosts.yml
vim inventories/production/group_vars/all.yml

# Teste conectividade
ansible all -m ping

# Aplique (dry-run primeiro)
ansible-playbook site.yml --check --diff
ansible-playbook site.yml

# Usar inventário de teste
ansible-playbook site.yml -i inventories/test/hosts.yml
```

> **Nota sobre transição de porta SSH:** A role `ssh` lida automaticamente com a mudança de porta. Se o servidor está na porta 22 e `ssh.port` está configurado para 2222, o playbook faz a transição sem perder conectividade (flush handlers → wait_for → set_fact → reset_connection).

## Inventário

```yaml
# inventories/production/hosts.yml
all:
  children:
    webservers:
      hosts:
        web01:
          ansible_host: 192.168.1.10
        web02:
          ansible_host: 192.168.1.11
    dbservers:
      hosts:
        db01:
          ansible_host: 192.168.1.20
```

### Variáveis por grupo/host

```
inventories/production/
├── hosts.yml
├── group_vars/
│   ├── all.yml            # Defaults globais (ssh.*, user.*, access.*)
│   └── webservers.yml     # Portas 80/443 para webservers
└── host_vars/
    └── web01.yml           # Overrides específicos do host
```

Hierarquia de precedência: `role defaults → group_vars/all → group_vars/<grupo> → host_vars/<host> → CLI`

## Principais variáveis (group_vars/all.yml)

```yaml
# SSH
ssh:
  port: 2222
  password_auth: "no"
  permit_root_login: "no"
  allow_groups: "ssh-access"

# Usuário admin
user:
  admin:
    name: feuser
    home: /home/feuser
    groups: [sudo, adm]
    ssh:
      authorized_key: ""         # ssh-ed25519 AAAA...
      exclusive: true            # default seguro: remove outras chaves do authorized_keys

# Servidor
server_hostname: ""              # vazio = não altera
server_timezone: UTC

# Access (firewall/fail2ban)
access:
  firewall:
    allowed_ports: [80, 443]     # Portas adicionais (SSH é gerido separadamente)
    allowed_ips: []              # ["10.0.0.0/8"]
    ssh_restrict_to_lan: true    # Restringe SSH à LAN
  fail2ban:
    bantime: 604800              # 1 semana
    maxretry: 5

# Updates
auto_reboot: false
notify_email: ""
```

Para manter chaves existentes além da `authorized_key` gerenciada pelo playbook, faça override explícito com `user.admin.ssh.exclusive: false` (ou `admin_ssh_key_exclusive: false` para compatibilidade legada).

## Estrutura do projeto

```
easy-infra/
├── ansible.cfg
├── site.yml                         # Playbook principal
├── inventories/
│   ├── production/                  # Servidores de produção
│   ├── staging/                     # Ambiente de staging
│   └── test/                        # Servidor de teste (homelab)
├── roles/
│   ├── etckeeper/                   # Versionamento /etc com git
│   ├── base/                        # Hostname, timezone, pacotes
│   ├── debloat/                     # Remoção de bloatware
│   ├── ssh/                         # Hardening SSH + transição de porta
│   ├── firewall/                    # UFW + limpeza de regras legadas
│   ├── users/                       # Admin user, sudo, keys, root lock
│   ├── fail2ban/                    # Brute-force protection
│   ├── auditd/                      # Auditoria do sistema
│   ├── updates/                     # Unattended-upgrades
│   └── monitoring/                  # sysstat, logwatch, server-health
├── docs/                            # Convenções agile-issues
├── guides/                          # Guias do workflow
└── templates/                       # Templates de issues
```

## Idempotência

Todos os módulos Ansible são nativamente idempotentes:

- `apt` — instala apenas se não presente, `cache_valid_time` evita updates desnecessários
- `template` — aplica apenas se conteúdo mudou, com `validate` antes
- `ufw` — não duplica regras existentes, limpa regras legadas automaticamente
- `user` — não recria usuário existente
- `authorized_key` — não duplica chaves
- Handlers — restart apenas quando notificados (config mudou)
- SSH port transition — `flush_handlers` + `reset_connection` apenas quando porta muda

Reaplicar em servidor já configurado: **zero mudanças, zero risco.**
Testado com 4 execuções consecutivas em Debian 13: `ok=57, changed=0` a partir da 2a execução.

## Compatibilidade

- Debian 12+ (testado em Debian 13 trixie)
- Ubuntu 22.04+
- Ansible 2.14+ no control node

## Histórico

Este projeto começou como bash scripts e foi migrado para Ansible após decisão arquitetural (ADR #2) para suportar gestão de N servidores com idempotência nativa. Os scripts legados foram removidos após a migração completa.

## Licença

MIT
