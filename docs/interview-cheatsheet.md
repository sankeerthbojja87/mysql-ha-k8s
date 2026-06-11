# Interview Cheatsheet

## Standalone MySQL

I deployed standalone MySQL on Kubernetes using a StatefulSet, PVC, Service, ConfigMap, Secret, readiness/liveness probes, and resource requests/limits. I validated DNS connectivity, user access, persistence, config values, and basic SQL operations.

## InnoDB Cluster

I deployed a 3-node MySQL InnoDB Cluster using the official MySQL Operator. I validated the custom resource status, pod readiness, PVCs, Group Replication member state, primary/secondary roles, replication queues, applier errors, MySQL Router health, and client connectivity through the Router service.

## Operator Pattern

The MySQL Operator installs CRDs such as `InnoDBCluster`. Kubernetes stores the desired state, and the operator reconciles it into StatefulSets, Pods, Services, PVCs, Router deployments, and MySQL cluster metadata.

## Why Operator In Separate Namespace

The operator is the control plane and the database cluster is the data plane. Keeping them separate improves lifecycle management, RBAC boundaries, troubleshooting, and allows one operator to manage multiple MySQL clusters.

## Router Issue Troubleshooting

If DB pods are running but Router is crashing, I do not assume the service is healthy. I inspect Router logs, deployment status, EndpointSlices, InnoDBCluster status, MySQL Shell cluster status, and Group Replication member state.

## Slow Query Triage

I capture the SQL, inspect `EXPLAIN` or `EXPLAIN ANALYZE`, check slow query logs, evaluate cardinality and access pattern, create a targeted composite index, then compare before/after plan and latency.

## Backup And Restore

For logical backups, I use `mysqldump --single-transaction` for InnoDB consistency and include routines, triggers, and events. In production, I validate restores regularly and track backup duration, failure rate, retention, encryption, and RTO.

## Rolling Config Update

I tested a config rollout by changing `max_connections` from 150 to 200. The CR desired state changed, but runtime did not. I traced the active MySQL config to `/etc/my.cnf.d/99-extra.cnf`, then to the operator-generated `mysql-ha-initconf` ConfigMap. After correcting the generated config in the lab and rolling the StatefulSet, I validated all members had `max_connections=200`.

## Sharding

Standard MySQL does not provide MongoDB-style native sharding. MySQL sharding is usually application-level or middleware-managed using a key such as tenant ID or customer ID. For production-scale sharding, I would evaluate Vitess for routing, topology, resharding, and operational workflows.
