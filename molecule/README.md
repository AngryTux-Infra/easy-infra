# Molecule Core Stability Scenarios

Scenarios stabilized for:
- `users`
- `ssh`
- `firewall`

Guidelines applied:
- pinned image tag (`geerlingguy/docker-debian12-ansible:bookworm`)
- no dependency on local pre-built integration image
- explicit `idempotence` in test sequence
