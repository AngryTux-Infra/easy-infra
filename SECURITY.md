# Security Policy

## Supported Versions

`main` is the only supported branch for security fixes.

## Reporting a Vulnerability

Do not open a public issue for suspected vulnerabilities.

Use private disclosure:
- email: `security@angrytux.com`
- include affected files/roles, impact, and reproduction steps
- include version/commit hash when possible

## Secrets Handling

- Never commit real secrets in `inventories/*/group_vars/*.yml`.
- Use `ansible-vault` for sensitive values.
- Keep vault password files out of git.

## Hardening Baseline

Baseline controls expected in production:
- SSH hardening (`role: ssh`)
- firewall + fail2ban (`roles: firewall`, `fail2ban`)
- audit logging (`role: auditd`)
- security patching (`role: updates`)
- integrity/host scans when enabled (`role: security_extra`)

## Operational Security Checks

Before merge:
- run syntax-check
- run lint/tests from CI
- review changes to `ansible.cfg`, SSH, firewall, and users carefully

After apply:
- verify SSH access paths (anti-lockout)
- verify timers/services expected by the changed role
