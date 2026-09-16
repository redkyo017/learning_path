# Day 34 — Source Reading Lab: Subscription Data Model in WSO2 APIM

## Goal

Trace the subscription data model in WSO2 APIM ACP source to understand how subscriptions are stored, retrieved, and managed. This is a **source reading** lab — no code to run, only exploration.

## Prerequisites

- WSO2 APIM ACP 4.7.0 source archive extracted to `/Users/hunghan/Downloads/wso2am-acp-4.7.0`
- A text editor or IDE for reading Java source files
- `grep` and `find` utilities available in your terminal

## Steps

### Step 1: Find ApiMgtDAO.java

The `ApiMgtDAO` class is the primary data access object for API management operations in WSO2.

```bash
find /Users/hunghan/Downloads/wso2am-acp-4.7.0 -name "ApiMgtDAO.java" | head -3
```

**Expected output:**
```
.../wso2am-acp-4.7.0/repository/components/plugins/.../ApiMgtDAO.java
```

Note the path. You'll use it in subsequent searches.

### Step 2: Find Subscription Operations

Search for subscription-related method names and the `AM_SUBSCRIPTION` table reference:

```bash
APIMGR_DAO_PATH="/path/to/ApiMgtDAO.java"  # Use result from Step 1
grep -n "addSubscription\|getSubscriptionsByAPI\|getSubscriptionsByOwner\|AM_SUBSCRIPTION" "$APIMGR_DAO_PATH" | head -20
```

**What to look for:**
- `addSubscription(...)` method signature
- SQL INSERT statements for `AM_SUBSCRIPTION`
- Column names in the table definition
- Query patterns for retrieving subscriptions

**Exercise:** Copy the first 5 lines of output here:
```
[Your findings]
```

### Step 3: Examine the addSubscription() Method

Find the full method definition:

```bash
grep -A 30 "void addSubscription\|boolean addSubscription" "$APIMGR_DAO_PATH" | head -40
```

**Questions to answer:**
1. What parameters does `addSubscription()` accept?
2. What columns does it INSERT into `AM_SUBSCRIPTION`?
3. What is the default value for `SUBSCRIPTION_STATUS`?

**Exercise:** Paste the method signature and first 10 lines of the implementation:
```
[Your findings]
```

### Step 4: Find Application Operations

Search for application-related methods:

```bash
grep -n "addApplication\|getApplicationsByOwner\|generateConsumer" "$APIMGR_DAO_PATH" | head -10
```

**What to look for:**
- `addApplication(...)` method
- Where ConsumerKey/ConsumerSecret are generated or stored
- Application lookup patterns

**Exercise:** List the line numbers of the top 3 matches:
```
[Your findings]
```

### Step 5: Compare Two Query Patterns

Using your findings from Steps 2 and 4, analyze these two queries:

**Query A:** Get all subscriptions for an API (from `getSubscriptionsByAPI`)
**Query B:** Get all subscriptions for an app owner (from `getSubscriptionsByOwner`)

**Exercise:** Write pseudoSQL for both queries based on the source:

**Query A (Publisher View — by API):**
```sql
SELECT ... FROM AM_SUBSCRIPTION WHERE ...
```

**Query B (Consumer View — by Owner):**
```sql
SELECT ... FROM AM_SUBSCRIPTION WHERE ...
```

### Step 6: Answer the Reflection Questions

**Q1: What columns does AM_SUBSCRIPTION hold?**

Based on your grep results, list the columns you found in the INSERT or SELECT statements:
```
[Your answer]
```

**Q2: What is the difference between TIER_ID in AM_SUBSCRIPTION and in AM_POLICY_SUBSCRIPTION?**

**Hint:** Search for `AM_POLICY_SUBSCRIPTION` in the file. How are these tables related?

```bash
grep -n "AM_POLICY_SUBSCRIPTION" "$APIMGR_DAO_PATH" | head -5
```

**Your answer:**
```
AM_SUBSCRIPTION.TIER_ID:
  [Your findings]

AM_POLICY_SUBSCRIPTION:
  [Your findings]
```

**Q3: How does ApiMgtDAO.getSubscriptionsByAPI() differ from getSubscriptionsByOwner()?**

Based on your source reading:
```
getSubscriptionsByAPI():
  [Your findings about what this query does and who uses it]

getSubscriptionsByOwner():
  [Your findings about what this query does and who uses it]
```

## Verification Checklist

- [ ] Found `ApiMgtDAO.java` in the WSO2 source
- [ ] Located at least 3 subscription-related methods
- [ ] Identified the columns in `AM_SUBSCRIPTION` table
- [ ] Distinguished between `TIER_ID` in two tables
- [ ] Explained the difference between Publisher and Consumer views
- [ ] Noted the default `SUBSCRIPTION_STATUS` value

## Key Takeaways

1. **Subscriptions are soft-deleted**, not hard-deleted. The `SUBSCRIPTION_STATUS` column gate controls access.
2. **Two access patterns**: Publisher queries by API ID; Consumer queries by app owner. Different queries serve different use cases.
3. **Tier is a foreign key**: `TIER_ID` references `AM_POLICY_SUBSCRIPTION`, not a string. This allows tiers to be versioned and updated.
4. **Audit fields** (`CREATED_BY`, `CREATED_TIME`, `UPDATED_BY`, `UPDATED_TIME`) are essential for compliance and debugging.

## Next Steps

Day 35 will implement these patterns in Go with an in-memory store and a validate endpoint.
