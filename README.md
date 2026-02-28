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
| `base` | Hostname, timezone, locale, NTP, pacotes essenciais | `base` |
| `ssh` | Hardening SSH — key-only, porta customizável, criptografia moderna | `ssh` |
| `firewall` | UFW deny-by-default, rate limiting SSH, portas/IPs configuráveis | `firewall` |
| `users` | Usuário admin, sudo sem senha, authorized_keys | `users` |
| `fail2ban` | Proteção brute-force SSH + jail recidive (ban progressivo) | `fail2ban` |
| `updates` | unattended-upgrades para security patches automáticos | `updates` |
| `monitoring` | sysstat, logwatch, comando `server-health` | `monitoring` |

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
```

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
│   ├── all.yml            # Defaults globais (ssh_port, admin_user, etc)
│   └── webservers.yml     # Portas 80/443 para webservers
└── host_vars/
    └── web01.yml           # Overrides específicos do host
```

Hierarquia de precedência: `role defaults → group_vars/all → group_vars/<grupo> → host_vars/<host> → CLI`

## Principais variáveis (group_vars/all.yml)

```yaml
# SSH
ssh_port: 2222
ssh_password_auth: false
ssh_permit_root_login: false

# Usuário admin
admin_user: sysadmin
admin_groups: [sudo, adm]
admin_ssh_key: ""               # ssh-ed25519 AAAA...

# Servidor
server_hostname: ""              # vazio = não altera
server_timezone: UTC

# Firewall
allowed_ports: []                # ["80/tcp", "443/tcp"]
firewall_allowed_ips: []         # ["10.0.0.0/8"]

# Fail2ban
f2b_bantime: 3600
f2b_maxretry: 5

# Updates
auto_reboot: false
notify_email: ""
```

## Estrutura do projeto

```
easy-infra/
├── ansible.cfg
├── site.yml                         # Playbook principal
├── inventories/
│   ├── production/
│   │   ├── hosts.yml
│   │   └── group_vars/all.yml
│   └── staging/
│       ├── hosts.yml
│       └── group_vars/all.yml
├── roles/
│   ├── base/                        # Hostname, timezone, pacotes
│   ├── ssh/                         # Hardening SSH (ADR #5)
│   ├── firewall/                    # UFW
│   ├── users/                       # Admin user, sudo, keys
│   ├── fail2ban/                    # Brute-force protection
│   ├── updates/                     # Unattended-upgrades
│   └── monitoring/                  # sysstat, server-health
├── scripts/                         # Codebase bash original (referência)
├── configs/                         # Configs bash originais (referência)
├── docs/                            # Convenções agile-issues
├── guides/                          # Guias do workflow
└── templates/                       # Templates de issues
```

## Idempotência

Todos os módulos Ansible são nativamente idempotentes:

- `apt` — instala apenas se não presente
- `template` — aplica apenas se conteúdo mudou, com `validate` antes
- `ufw` — não duplica regras existentes
- `user` — não recria usuário existente
- `authorized_key` — não duplica chaves
- Handlers — restart apenas quando notificados (config mudou)

Reaplicar em servidor já configurado: **zero mudanças, zero risco.**

## Compatibilidade

- Debian 12+
- Ubuntu 22.04+
- Ansible 2.14+ no control node

## Histórico

Este projeto começou como bash scripts (preservados em `scripts/` como referência) e foi migrado para Ansible após decisão arquitetural (ADR #2) para suportar gestão de N servidores com idempotência nativa.

## Licença

MIT
