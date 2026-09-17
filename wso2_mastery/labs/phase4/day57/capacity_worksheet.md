# WSO2 ECS Fargate Capacity Worksheet

Use this worksheet to estimate and validate your WSO2 API Manager deployment capacity.

Fill in the **Your Value** column based on your load testing results, production metrics, or estimates.
All formulas are provided; use them to derive capacity requirements.

---

## Part 1: Input Variables

These are measured or configured values for your deployment.

| Variable | Description | Formula/Measurement | Example | Your Value |
|---|---|---|---|---|
| **token_issue_rate_per_sec** | Average tokens issued per second | Measure from IS logs or estimate from login frequency | 20 | |
| **peak_token_issue_rate_per_sec** | Peak tokens issued per second (e.g., during business hours) | Measure from load test or CloudWatch IS metrics | 50 | |
| **avg_token_ttl_sec** | Average token time-to-live in seconds | From IS config (default 3600s = 1 hour) | 3600 | |
| **peak_rps** | Peak requests per second across all APIs | From load test or CloudWatch GW metrics | 3000 | |
| **avg_rps** | Average requests per second (normal load) | From CloudWatch GW metrics (daily average) | 1000 | |
| **rps_per_gw_task_at_target** | RPS per GW task at 60% CPU target | From Day 55 Exercise 1: ~1200 RPS per 1 vCPU task | 1200 | |
| **backend_safe_rps** | Maximum RPS your backend can handle | From backend load test | 500 | |
| **cpu_target_pct** | ECS autoscaling CPU target percentage | Terraform value (default 60%) | 60 | |
| **gw_task_cpu** | CPU allocated to each GW task (in vCPU) | ECS task definition (default 1024 CPU = 1 vCPU) | 1 | |
| **gw_task_memory_mb** | Memory allocated to each GW task (in MB) | ECS task definition (default 2048 MB) | 2048 | |
| **is_task_memory_mb** | Memory allocated to each IS task (in MB) | ECS task definition (default 2048 MB) | 2048 | |
| **session_size_kb** | Average memory per session/token | Estimate ~2 KB per token | 2 | |
| **jvm_overhead_mb** | JVM and WSO2 runtime overhead | Typical WSO2 Java app: 800–1200 MB | 1000 | |
| **unique_users** | Estimated number of unique users in steady state | From your user base estimate | 10000 | |

---

## Part 2: Derived Metrics

Use the formulas below to calculate deployment requirements.

### IS (Identity Server) Session Capacity

| Metric | Formula | Calculation | Your Result |
|---|---|---|---|
| **steady_state_sessions** | `token_issue_rate_per_sec × avg_token_ttl_sec` | 20 × 3600 | |
| **peak_sessions** | `peak_token_issue_rate_per_sec × avg_token_ttl_sec` | 50 × 3600 | |
| **session_ram_mb** | `steady_state_sessions × session_size_kb / 1024` | 72000 × 2 / 1024 ≈ 141 MB | |
| **peak_session_ram_mb** | `peak_sessions × session_size_kb / 1024` | 180000 × 2 / 1024 ≈ 352 MB | |
| **total_is_ram_needed_mb** | `session_ram_mb + jvm_overhead_mb` | 141 + 1000 = 1141 MB | |
| **is_ram_headroom_mb** | `is_task_memory_mb - total_is_ram_needed_mb` | 2048 - 1141 = 907 MB | |
| **per_user_session_count** | `steady_state_sessions / unique_users` | 72000 / 10000 = 7.2 sessions | |

### GW (Gateway) Task Scaling

| Metric | Formula | Calculation | Your Result |
|---|---|---|---|
| **gw_scale_trigger_rps_per_task** | `rps_per_gw_task_at_target × (cpu_target_pct / 100)` | 1200 × (60 / 100) = 720 RPS | |
| **gw_tasks_for_avg_load** | `ceil(avg_rps / rps_per_gw_task_at_target)` | ceil(1000 / 1200) = 1 | |
| **gw_tasks_for_peak_load** | `ceil(peak_rps / rps_per_gw_task_at_target)` | ceil(3000 / 1200) = 3 | |
| **gw_min_capacity** | Minimum tasks to keep online (at least 1) | 1 | |
| **gw_max_capacity** | Max tasks; must be ≥ gw_tasks_for_peak_load | 3 or higher (e.g., 4 for buffer) | |

### Throttle Policy Sizing

| Metric | Formula | Calculation | Your Result |
|---|---|---|---|
| **throttle_headroom_fraction** | `1 - (0.2)` = 0.8 (20% headroom for autoscaling lag) | 0.8 | |
| **throttle_safe_rps** | `backend_safe_rps × throttle_headroom_fraction` | 500 × 0.8 = 400 RPS | |
| **throttle_gold_req_per_min** | `throttle_safe_rps × 60` | 400 × 60 = 24,000 req/min | |
| **throttle_silver_req_per_min** | `throttle_gold_req_per_min × 0.5` (50% of Gold) | 24000 × 0.5 = 12,000 req/min | |
| **throttle_bronze_req_per_min** | `throttle_gold_req_per_min × 0.25` (25% of Gold) | 24000 × 0.25 = 6,000 req/min | |

### Capacity Headroom

| Metric | Formula | Calculation | Your Result |
|---|---|---|---|
| **is_headroom_pct** | `(is_ram_headroom_mb / is_task_memory_mb) × 100` | (907 / 2048) × 100 ≈ 44% | |
| **gw_headroom_rps** | `(gw_max_capacity × rps_per_gw_task_at_target) - peak_rps` | (4 × 1200) - 3000 = 1800 RPS | |

---

## Part 3: Sanity Checks

Validate your calculations against these constraints:

- [ ] **IS Session RAM is safe:** `total_is_ram_needed_mb < (is_task_memory_mb - 500)` → Leaves 500 MB for JVM growth.
  - If NOT safe: Increase `is_task_memory_mb` or reduce `avg_token_ttl_sec` (shorter token lifetime).

- [ ] **IS sessions per user are reasonable:** `per_user_session_count < MaxSessionsPerUser` (default 100).
  - If NOT safe: Increase `MaxSessionsPerUser` in IS config or reduce token lifetime.

- [ ] **GW max capacity is sufficient:** `gw_max_capacity >= gw_tasks_for_peak_load`.
  - If NOT safe: Increase `gw_max_capacity` in Terraform or reduce `cpu_target_pct` (e.g., 50% instead of 60%).

- [ ] **Throttle limit protects backend:** `throttle_gold_req_per_min <= backend_safe_rps × 60`.
  - If NOT safe: Your backend could be overloaded. Increase backend capacity or lower throttle limit.

- [ ] **GW headroom exists:** `gw_headroom_rps > 0`.
  - If NOT safe: No buffer for traffic spikes. Increase `gw_max_capacity`.

- [ ] **IS headroom exists:** `is_headroom_pct > 20`.
  - If NOT safe: IS RAM is nearly full. Risk of OOM errors. Increase `is_task_memory_mb` or reduce token lifetime.

---

## Part 4: Configuration Updates

### IS Configuration (identity.xml)

File: `<IS_HOME>/repository/conf/identity/identity.xml`

Update the session limit:

```xml
<MaxSessionsPerUser>100</MaxSessionsPerUser>
```

Calculate your value:
```
MaxSessionsPerUser = ceil(per_user_session_count × 1.5)  # 1.5× buffer for bursts
Example: ceil(7.2 × 1.5) = 11 → set to 100 (default safe)
```

Your value: `MaxSessionsPerUser = ___`

### Throttle Policy Update (CP REST API)

Apply throttle limits via the CP Admin API:

**Gold tier (premium API consumers):**
```bash
curl -X PUT https://cp.wso2.internal:9443/api/am/admin/v4/throttling/policies/subscription/Gold \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Gold",
    "description": "Premium API tier",
    "defaultLimit": {
      "requestCount": {
        "requestCount": 24000,
        "timeUnit": "min",
        "unitTime": 1
      }
    }
  }' \
  -k
# TODO: Replace $ADMIN_TOKEN with your CP admin API token
```

Your Gold tier limit: `requestCount = ___`

**Silver tier (standard API consumers):**
```bash
curl -X PUT https://cp.wso2.internal:9443/api/am/admin/v4/throttling/policies/subscription/Silver \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Silver",
    "description": "Standard API tier",
    "defaultLimit": {
      "requestCount": {
        "requestCount": 12000,
        "timeUnit": "min",
        "unitTime": 1
      }
    }
  }' \
  -k
```

Your Silver tier limit: `requestCount = ___`

**Bronze tier (community API consumers):**
```bash
curl -X PUT https://cp.wso2.internal:9443/api/am/admin/v4/throttling/policies/subscription/Bronze \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Bronze",
    "description": "Community API tier",
    "defaultLimit": {
      "requestCount": {
        "requestCount": 6000,
        "timeUnit": "min",
        "unitTime": 1
      }
    }
  }' \
  -k
```

Your Bronze tier limit: `requestCount = ___`

### ECS Task Definition Updates (Terraform)

Update `labs/phase4/day56/variables.tf` with your calculated values:

```hcl
# Example: if your load test shows 5000 peak RPS, you need 5 GW tasks
variable "gw_max_capacity" {
  default = 5  # Update based on gw_tasks_for_peak_load + buffer
}

variable "tm_max_capacity" {
  default = 2  # Usually 2; TM is event-fanout, not linear
}
```

Your Terraform updates:
- `gw_max_capacity = ___`
- `tm_max_capacity = ___`
- `gw_cpu_target = ___` (default 60)
- `is_task_memory_mb = ___` (default 2048, increase if needed)

---

## Part 5: Monitoring & Review

### CloudWatch Dashboards

Monitor these metrics after deployment:

- **GW CPU:** Should hover around 60% at average load; spike to 80% is alarm threshold.
- **GW Task Count:** Should track with traffic. Peaks at `gw_tasks_for_peak_load` during load spikes.
- **IS CPU:** Should be < 50% at average load. > 70% sustained = upgrade IS or reduce token TTL.
- **IS Heap:** Monitor JVM memory. If > 80% of `is_task_memory_mb`, you risk OOM.
- **Throttle Policy Hits:** Count of requests rejected due to throttle. Should be 0 for Gold tier under normal load.

### Review Triggers

Revisit this worksheet when:
- Peak RPS exceeds `gw_tasks_for_peak_load × rps_per_gw_task_at_target` by > 10%.
- IS CPU sustained > 70% for a week.
- IS session count > 150,000 (approaching memory limits).
- Token issuance rate > 100 tokens/sec.
- Backend load test shows `backend_safe_rps` has changed (e.g., hardware upgrade).

---

## Example: Completed Worksheet

**Scenario:** A fintech API with 10,000 users, 20 token issuances per second, peak 3000 RPS.

| Variable | Example Value |
|---|---|
| token_issue_rate_per_sec | 20 |
| peak_token_issue_rate_per_sec | 50 |
| avg_token_ttl_sec | 3600 |
| peak_rps | 3000 |
| avg_rps | 1000 |
| rps_per_gw_task_at_target | 1200 |
| backend_safe_rps | 500 |
| unique_users | 10000 |

**Derived Metrics:**

| Metric | Result |
|---|---|
| steady_state_sessions | 72,000 |
| session_ram_mb | 141 MB |
| total_is_ram_needed_mb | 1,141 MB |
| gw_tasks_for_peak_load | 3 |
| throttle_gold_req_per_min | 24,000 |
| per_user_session_count | 7.2 |

**Sanity Checks:**
- ✓ IS RAM safe (1,141 < 1,548 MB)
- ✓ Per-user sessions safe (7.2 < 100)
- ✓ GW capacity safe (max 4 ≥ needed 3)
- ✓ Throttle limit protects backend (24,000 req/min ≈ 400 RPS < 500 RPS backend safe)
- ✓ GW headroom (1200 RPS)
- ✓ IS headroom (44%)

**Configuration:**
- `MaxSessionsPerUser = 100` (default is safe)
- `gw_max_capacity = 4` (3 needed + 1 buffer)
- Gold tier: 24,000 req/min
- Silver tier: 12,000 req/min
- Bronze tier: 6,000 req/min

---

## Summary

Use this worksheet to:
1. **Estimate capacity** — Input your load test results.
2. **Validate sizing** — Run the formulas and check against sanity checks.
3. **Configure infrastructure** — Update Terraform, IS config, throttle policies.
4. **Monitor in production** — Track metrics; revisit worksheet when load changes.
5. **Plan scaling** — When sanity checks fail, you know what needs to be upgraded.

**Next step:** Run this worksheet **before** you provision infrastructure. Revisit it quarterly or when business metrics change.
