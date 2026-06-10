# Backup And Restore

## Logical Backup

Create a logical backup through Router:

```bash
kubectl config set-context --current --namespace=mysql-ha

kubectl run mysql-backup-client \
  --rm -i \
  --quiet \
  --image=mysql:8.4 \
  --restart=Never \
  -- mysqldump \
    -hmysql-ha \
    -uroot \
    -p'RootPass-MySQL-HA-Lab-123!' \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --all-databases \
  > mysql-ha-backup-$(date +%Y%m%d-%H%M%S).sql
```

Validate:

```bash
ls -lh mysql-ha-backup-*.sql
tail -5 mysql-ha-backup-*.sql
```

## Restore To Another Database

Create restore database:

```bash
kubectl run mysql-ha-client --rm -it \
  --image=mysql:8.4 \
  --restart=Never \
  -- mysql -hmysql-ha -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  -e "CREATE DATABASE IF NOT EXISTS restoredb;"
```

Restore a single database dump:

```bash
kubectl run mysql-restore-client \
  --rm -i \
  --quiet \
  --image=mysql:8.4 \
  --restart=Never \
  -- mysql -hmysql-ha -uroot -p'RootPass-MySQL-HA-Lab-123!' restoredb \
  < appdb-backup.sql
```

For an `--all-databases` dump, restore as-is into the target instance:

```bash
kubectl run mysql-restore-client \
  --rm -i \
  --quiet \
  --image=mysql:8.4 \
  --restart=Never \
  -- mysql -hmysql-ha -uroot -p'RootPass-MySQL-HA-Lab-123!' \
  < mysql-ha-backup.sql
```

## Production Considerations

- Use encrypted object storage for backups.
- Validate restores regularly.
- Define retention policy.
- Separate logical and physical backup strategies.
- Monitor backup duration, failure rate, and restore time objective.

