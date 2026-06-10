# MySQL Performance Triage

## Simulated Slow Query Scenario

Create test data:

```bash
kubectl exec -it mysql-0 -- mysql -uroot -p'RootPass-MySQL-Lab-123!' appdb -e "
CREATE TABLE IF NOT EXISTS orders (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  status VARCHAR(20) NOT NULL,
  region VARCHAR(20) NOT NULL,
  order_total DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP NOT NULL
);

SET SESSION cte_max_recursion_depth = 60000;

INSERT INTO orders (customer_id, status, region, order_total, created_at)
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 50000
)
SELECT
  FLOOR(1 + RAND() * 5000),
  ELT(FLOOR(1 + RAND() * 4), 'NEW', 'PAID', 'SHIPPED', 'CANCELLED'),
  ELT(FLOOR(1 + RAND() * 4), 'US', 'EU', 'APAC', 'LATAM'),
  ROUND(RAND() * 1000, 2),
  NOW() - INTERVAL FLOOR(RAND() * 365) DAY
FROM seq;
"
```

Problem query:

```sql
SELECT id, customer_id, status, region, order_total, created_at
FROM orders
WHERE customer_id = 1234
  AND status = 'PAID'
ORDER BY created_at DESC
LIMIT 10;
```

Explain:

```bash
kubectl exec -it mysql-0 -- mysql -uroot -p'RootPass-MySQL-Lab-123!' appdb -e "
EXPLAIN ANALYZE
SELECT id, customer_id, status, region, order_total, created_at
FROM orders
WHERE customer_id = 1234
  AND status = 'PAID'
ORDER BY created_at DESC
LIMIT 10;
"
```

Add composite index:

```bash
kubectl exec -it mysql-0 -- mysql -uroot -p'RootPass-MySQL-Lab-123!' appdb -e "
CREATE INDEX idx_orders_customer_status_created
ON orders (customer_id, status, created_at DESC);
"
```

Validate index:

```bash
kubectl exec -it mysql-0 -- mysql -uroot -p'RootPass-MySQL-Lab-123!' appdb -e "
SHOW INDEX FROM orders;
EXPLAIN ANALYZE
SELECT id, customer_id, status, region, order_total, created_at
FROM orders
WHERE customer_id = 1234
  AND status = 'PAID'
ORDER BY created_at DESC
LIMIT 10;
"
```

## Interview Framing

When an app team reports query latency without app-side changes, capture the SQL, inspect `EXPLAIN` or `EXPLAIN ANALYZE`, check slow query logs, validate cardinality and access pattern, create the smallest useful composite index, and measure before/after behavior.

