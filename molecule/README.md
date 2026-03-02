# Molecule Scenarios

Scenarios added for role-level coverage:
- `base`
- `debloat`
- `etckeeper`
- `fail2ban`
- `auditd`
- `security_extra`
- `updates`
- `monitoring`

Run one scenario:

```bash
molecule test -s base
```

Run all scenarios:

```bash
for s in base debloat etckeeper fail2ban auditd security_extra updates monitoring; do
  molecule test -s "$s"
done
```
