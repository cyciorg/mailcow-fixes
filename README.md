# Mailcow Fixes

what we aim with this is to fix our mail server for scalability and reliability.

## Upcoming
- Ability to link Stripe or other payment gateways to mailcow.
- Offsite backups with these scripts and not just with borgmatic.

### Scripts
- backup-and-restore-single: adds functionality to backup a single users vmail data. including SQL.
- backup-and-restore-domain: adds functionality to backup an entire domains vmail data.
```bash
  ./helper-scripts/backup-and-restore-single.sh -b /backup/path user@server.com
  ./helper-scripts/backup-and-restore-single.sh -r user@server.com /backup/path

  ./helper-scripts/backup-and-restore-domain.sh -b /backup/path server.com
  ./helper-scripts/backup-and-restore-domain.sh -r server.com /backup/path

```
