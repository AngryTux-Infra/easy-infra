# Role: auditd

## Purpose

Configure and enforce the baseline for the domain handled by this role.

## Usage

Run this role via tags:

~~~bash
ansible-playbook site.yml --tags auditd
~~~

## Variables

Role defaults (when present):
- roles/auditd/defaults/main.yml

Override via inventory:
- inventories/<env>/group_vars/*.yml
- inventories/<env>/host_vars/*.yml

## Tasks

Main tasks file:
- roles/auditd/tasks/main.yml

## Idempotency Notes

This role should be idempotent. Re-applying should avoid unnecessary changes.

## Validation

Recommended syntax check:

~~~bash
ansible-playbook -i inventories/test/hosts.yml site.yml --tags auditd --syntax-check
~~~
