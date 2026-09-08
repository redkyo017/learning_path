-- 10-generate.sql
-- Deterministic data generator for the `payments` database, run after
-- 00-schema.sql. Every run at the same SCALE produces identical data,
-- because later labs' verify.sh scripts assert on concrete numbers.
--
-- setseed() must be the very first statement: everything downstream draws
-- from Postgres' per-session random() stream, and that stream is only
-- reproducible if it starts from a known state before any other query
-- touches it.
SELECT setseed(0.42);

-- Parallel workers each get their own random() stream, and worker
-- scheduling is not guaranteed to line up the same way on every run.
-- Force single-threaded execution for this whole session so the sequence
-- of random() draws below is identical run to run.
SET max_parallel_workers_per_gather = 0;

\if :{?scale}
\else
  \set scale 10
\endif

\echo 'Generating seed data at SCALE =' :scale

-- Derived row counts at this SCALE (see database_mastery/labs/stack/seed/README.md
-- for the table at SCALE=10 and SCALE=2):
--   merchants        2000    * :scale / 10
--   customers        500000  * :scale / 10
--   payments         5000000 * :scale / 10
--   ledger_entries   10000000 * :scale / 10   (exactly 2 per payment)
-- All of these are computed as NUMBER::bigint * :scale / 10 rather than
-- (NUMBER * :scale / 10)::bigint, so the multiplication itself happens in
-- bigint arithmetic instead of overflowing int4 before the cast applies
-- at very large SCALE.

-- ---------------------------------------------------------------------
-- merchants
-- ---------------------------------------------------------------------
-- country is drawn from a weighted list so US/GB/DE/FR/JP/SG/BR appear at
-- different frequencies (not a uniform 1/7 each). risk_tier is correlated
-- with country: the six "developed market" countries skew toward lower
-- risk tiers, BR skews higher.
--
-- Every random() draw is hoisted into the MATERIALIZED `merchant_gen`
-- CTE below, including the country draw's own r value (via the nested
-- `(SELECT random() AS r) rr` so the four-way CASE re-reads one column
-- instead of re-invoking random() per WHEN branch). Neither the country
-- LATERAL nor payment_methods' method-count LATERAL below references its
-- outer row, so nothing stops a planner from treating them as
-- evaluate-once rather than evaluate-per-row -- for country that failure
-- mode is silent and catastrophic (every merchant would draw the same
-- country, destroying Day 4's correlation lesson), so this is hoisted
-- for rigor, not because it has been observed to misbehave.
WITH merchant_gen AS MATERIALIZED (
    SELECT
        gs AS merchant_id,
        CASE
            WHEN r < 0.30 THEN 'US'
            WHEN r < 0.45 THEN 'GB'
            WHEN r < 0.60 THEN 'DE'
            WHEN r < 0.72 THEN 'FR'
            WHEN r < 0.84 THEN 'JP'
            WHEN r < 0.92 THEN 'SG'
            ELSE 'BR'
        END AS country,
        random() AS risk_r,
        random() AS created_offset_r
    FROM generate_series(1, 2000::bigint * :scale / 10) AS gs
    CROSS JOIN LATERAL (SELECT random() AS r) rr
)
INSERT INTO merchants (merchant_id, name, country, risk_tier, created_at)
SELECT
    mg.merchant_id,
    'Merchant ' || lpad(mg.merchant_id::text, 6, '0') AS name,
    mg.country,
    CASE
        WHEN mg.country IN ('US', 'GB', 'DE', 'FR', 'JP', 'SG')
            THEN (1 + floor(mg.risk_r * 3))::smallint
        ELSE (3 + floor(mg.risk_r * 3))::smallint
    END AS risk_tier,
    TIMESTAMPTZ '2022-01-01 00:00:00+00' + (mg.created_offset_r * interval '600 days') AS created_at
FROM merchant_gen mg;

-- ---------------------------------------------------------------------
-- customers
-- ---------------------------------------------------------------------
-- No LATERAL here (country and created_at are drawn directly in the
-- SELECT list against generate_series, not through a subquery join), so
-- there is no plan-order hazard to hoist against.
INSERT INTO customers (customer_id, email, country, created_at)
SELECT
    gs AS customer_id,
    'customer' || gs::text || '@example.test' AS email,
    (ARRAY['US', 'GB', 'DE', 'FR', 'JP', 'SG', 'BR'])[1 + floor(random() * 7)::int] AS country,
    TIMESTAMPTZ '2022-01-01 00:00:00+00' + (random() * interval '900 days') AS created_at
FROM generate_series(1, 500000::bigint * :scale / 10) AS gs;

-- ---------------------------------------------------------------------
-- accounts: one per merchant, one per customer, plus one platform account
-- ---------------------------------------------------------------------
-- account_id space is partitioned by construction so every later table
-- that needs an owner's account_id can compute it by arithmetic instead
-- of joining against accounts (there is no index on accounts.owner_id to
-- join through, by design -- see 00-schema.sql):
--   merchant accounts:  account_id = merchant_id                        (1 .. merchant_count)
--   customer accounts:  account_id = merchant_count + customer_id
--   platform account:   account_id = merchant_count + customer_count + 1
--
-- balance_minor here is a provisional placeholder. Once ledger_entries
-- exists below, EVERY account's balance_minor (including the platform
-- account) is overwritten to `ledger_sum + 100000000000` -- a fixed
-- constant, not a computed one -- so the cache starts in an exact, known
-- relationship with the ledger. See the reconciliation UPDATE after the
-- ledger_entries insert.
INSERT INTO accounts (account_id, owner_type, owner_id, currency, balance_minor, created_at)
SELECT
    merchant_id AS account_id,
    'merchant' AS owner_type,
    merchant_id AS owner_id,
    CASE country
        WHEN 'US' THEN 'USD' WHEN 'GB' THEN 'GBP' WHEN 'DE' THEN 'EUR'
        WHEN 'FR' THEN 'EUR' WHEN 'JP' THEN 'JPY' WHEN 'SG' THEN 'SGD'
        WHEN 'BR' THEN 'BRL'
    END AS currency,
    0::bigint AS balance_minor,
    created_at
FROM merchants;

INSERT INTO accounts (account_id, owner_type, owner_id, currency, balance_minor, created_at)
SELECT
    2000::bigint * :scale / 10 + customer_id AS account_id,
    'customer' AS owner_type,
    customer_id AS owner_id,
    CASE country
        WHEN 'US' THEN 'USD' WHEN 'GB' THEN 'GBP' WHEN 'DE' THEN 'EUR'
        WHEN 'FR' THEN 'EUR' WHEN 'JP' THEN 'JPY' WHEN 'SG' THEN 'SGD'
        WHEN 'BR' THEN 'BRL'
    END AS currency,
    0::bigint AS balance_minor,
    created_at
FROM customers;

INSERT INTO accounts (account_id, owner_type, owner_id, currency, balance_minor, created_at)
VALUES (
    2000::bigint * :scale / 10 + 500000::bigint * :scale / 10 + 1,
    'platform', 0, 'USD', 0, TIMESTAMPTZ '2022-01-01 00:00:00+00'
);

-- ---------------------------------------------------------------------
-- payment_methods: 1-3 per customer
-- ---------------------------------------------------------------------
-- Two MATERIALIZED CTEs, for the same rigor reason as merchants above.
-- customer_method_count hoists the "how many methods does this customer
-- get" draw (1-3) so the value driving the LATERAL generate_series
-- expansion below is a plain, already-materialized integer column, not a
-- volatile expression -- the expansion itself then involves no
-- volatility at all. pm_gen then hoists the per-row brand/last4/exp
-- draws the same way payments' `gen` CTE does.
WITH customer_method_count AS MATERIALIZED (
    SELECT
        customer_id,
        (1 + floor(random() * 3))::int AS method_count
    FROM customers
),
pm_gen AS MATERIALIZED (
    SELECT
        cmc.customer_id,
        gs2.method_no,
        random() AS brand_r,
        random() AS last4_r,
        random() AS exp_month_r,
        random() AS exp_year_r
    FROM customer_method_count cmc
    CROSS JOIN LATERAL generate_series(1, cmc.method_count) AS gs2(method_no)
)
INSERT INTO payment_methods (payment_method_id, customer_id, brand, last4, exp_month, exp_year)
SELECT
    row_number() OVER (ORDER BY customer_id, method_no) AS payment_method_id,
    customer_id,
    (ARRAY['visa', 'mastercard', 'amex', 'discover'])[1 + floor(brand_r * 4)::int] AS brand,
    lpad(floor(last4_r * 10000)::text, 4, '0') AS last4,
    (1 + floor(exp_month_r * 12))::smallint AS exp_month,
    (2025 + floor(exp_year_r * 5))::smallint AS exp_year
FROM pm_gen;

-- Scratch mapping from customer_id to that customer's contiguous
-- payment_method_id range (payment_method_id was assigned in customer_id
-- order above, so min/count is enough to reconstruct it). This is a
-- session-local TEMP TABLE used only to make the payments insert below a
-- cheap arithmetic lookup instead of a per-row correlated subquery -- it
-- is not part of the canonical schema and is dropped once payments exists.
CREATE TEMP TABLE customer_pm_range AS
SELECT customer_id, min(payment_method_id) AS pm_start, count(*)::int AS pm_count
FROM payment_methods
GROUP BY customer_id;

ANALYZE customer_pm_range;

-- ---------------------------------------------------------------------
-- merchant_cdf: Zipf(s=1) cumulative distribution over merchant rank
-- ---------------------------------------------------------------------
-- Session-local scratch table (dropped below, not part of the canonical
-- schema), used the same way customer_pm_range is above: it turns "pick a
-- merchant from a skewed distribution" into an inverse-CDF lookup instead
-- of a formula evaluated inline.
--
-- merchant_id doubles as rank. weight(rank) = 1/rank, normalised by the
-- harmonic number H_N (N = merchant_count), so
-- P(merchant_id = k) = (1/k) / H_N -- a Zipf(s=1) distribution. For
-- N = 2000 (SCALE=10): H_20 (the top 1%, i.e. the 20 lowest merchant ids)
-- is approximately 3.598, and H_2000 is approximately 8.178
-- (H_n ~ ln(n) + gamma), so the top 1% of merchants receive roughly
-- 3.598 / 8.178 = 44.0% of payments, and merchant_id = 1 alone receives
-- roughly 1 / 8.178 = 12.2%. These are SCALE=10 figures specifically:
-- at SCALE=2 (merchant_count = 400, top 1% = 4 merchants), H_4 / H_400 is
-- approximately 2.083 / 6.569 = 31.7%, and the head merchant's share
-- rises to approximately 1 / 6.569 = 15.2% -- smaller N concentrates the
-- distribution's head less because there is less tail for it to dominate.
-- Anything asserting the 44%/12% figures specifically must run at
-- SCALE=10. See README.md's "Why the data is skewed" section for the
-- full arithmetic and the reasoning against a more extreme skew.
--
-- cum_prob is cast to float8, not left as the numeric that
-- `1.0 / merchant_id` naturally produces: merchant_r below is
-- double precision (random()'s return type), and numeric >= float8 has
-- no native operator, so an unindexed numeric->float8 cast would run on
-- every comparison and the CREATE INDEX below (built with numeric_ops)
-- would not satisfy the WHERE clause at all -- the planner would fall
-- back to scanning a large fraction of merchant_cdf per payment. With
-- both sides float8, the index is usable, and float8's ~6e-5 gaps at
-- this table's scale are far above the resolution needed to keep 2,000
-- distinct cumulative values distinct.
CREATE TEMP TABLE merchant_cdf AS
WITH weights AS (
    SELECT merchant_id AS rank, 1.0 / merchant_id AS weight
    FROM merchants
),
total AS (
    SELECT sum(weight) AS h FROM weights
)
SELECT
    rank AS merchant_id,
    (sum(weight) OVER (ORDER BY rank) / (SELECT h FROM total))::float8 AS cum_prob
FROM weights;

-- Force the highest rank to catch any draw that floating-point rounding
-- would otherwise let slip past the last real cum_prob (which lands only
-- very close to, not necessarily exactly, 1.0).
UPDATE merchant_cdf SET cum_prob = 2.0::float8
WHERE merchant_id = (SELECT max(merchant_id) FROM merchant_cdf);

CREATE INDEX ON merchant_cdf (cum_prob);
ANALYZE merchant_cdf;

-- The payments insert below joins merchants, customer_pm_range and
-- merchant_cdf. Analyze every input first: with no statistics at all the
-- planner could pick a nested-loop plan against an unanalyzed temp table
-- that would not finish in reasonable time. (It can no longer change the
-- *data*, only the runtime -- every random() draw the payments insert
-- needs is hoisted into the MATERIALIZED `gen` CTE below, so no volatile
-- function remains in the outer SELECT for a different join order to
-- reorder differently.)
ANALYZE merchants;
ANALYZE customers;
ANALYZE payment_methods;

-- ---------------------------------------------------------------------
-- payments: 5,000,000 * :scale / 10 rows
-- ---------------------------------------------------------------------
-- Every random() draw this insert needs is made exactly once, in the
-- MATERIALIZED `gen` CTE, and carried through the rest of the query as a
-- plain value. That is deliberate: MATERIALIZED forces Postgres to
-- compute and store `gen` before joining it to anything else, so no
-- matter what join order or plan the optimizer picks for the merchants /
-- customer_pm_range / merchant_cdf joins below, it cannot change how many
-- times random() is called or in what order -- only the join plan's
-- speed, never the data. Without this, a correlated subquery re-executed
-- in a different order per run could silently break the determinism
-- guarantee (see README.md).
--
-- merchant_id is chosen via merchant_cdf (see above): merchant_r is a
-- single uniform draw, and the outer query looks up the smallest
-- merchant_id whose cumulative probability covers it -- a Zipf(s=1) draw,
-- giving the top 1% of merchants roughly 44% of these rows at SCALE=10.
--
-- currency is the merchant's country's primary currency 95% of the time,
-- and a genuinely different currency (drawn from the other five, via
-- array_remove -- never the correct one, so the deviation is exactly 5%,
-- not diluted by an occasional coincidental match) the remaining 5% of
-- the time. A perfect country -> currency mapping would make the
-- planner's independence assumption look accidentally fine; no
-- correlation at all would make Day 4's extended-statistics fix look
-- irrelevant. Only a real, imperfect correlation makes that lesson land.
--
-- description is short for 19 rows in 20. For the twentieth, it is built
-- by concatenating 96 md5 hashes (96 * 32 = 3,072 bytes of high-entropy
-- hex) against a TOAST_TUPLE_THRESHOLD of 2,032 bytes -- a real margin,
-- not the ~10% margin 70 iterations (2,240 bytes) would leave a future
-- editor to accidentally erase. A single repeated character or phrase
-- would not work here: PostgreSQL's TOAST compressor (pglz) would shrink
-- that back under the threshold and store it inline, silently defeating
-- the exercise. High-entropy hex resists compression, so these rows
-- genuinely move description out of line into the TOAST table -- which is
-- the column Day 1 asks the learner to find. The md5 input is
-- payment_id and a loop counter only (no random()): fully deterministic,
-- and still different enough per iteration to stay incompressible.
WITH gen AS MATERIALIZED (
    SELECT
        gs AS payment_id,
        random() AS merchant_r,
        (1 + floor(random() * (500000::bigint * :scale / 10)))::bigint AS customer_id,
        (100 + floor(random() * 999900))::bigint AS amount_minor,
        random() AS status_r,
        random() AS currency_r,
        random() AS currency_alt_r,
        random() AS desc_r,
        random() AS pm_offset_r,
        random() AS captured_offset_r,
        TIMESTAMPTZ '2024-01-01 00:00:00+00'
            + (floor(random() * 548))::int * interval '1 day'
            + (
                CASE WHEN random() < 0.7
                     THEN 9 + floor(random() * 9)   -- 70% of payments land in a 09:00-17:59 business-hours window
                     ELSE floor(random() * 24)
                END
              )::int * interval '1 hour'
            + (floor(random() * 60))::int * interval '1 minute'
            + (floor(random() * 60))::int * interval '1 second' AS created_at
    FROM generate_series(1, 5000000::bigint * :scale / 10) AS gs
)
INSERT INTO payments (
    payment_id, merchant_id, customer_id, payment_method_id,
    amount_minor, currency, status, created_at, captured_at, description
)
SELECT
    g.payment_id,
    mcdf.merchant_id,
    g.customer_id,
    cpr.pm_start + floor(g.pm_offset_r * cpr.pm_count)::bigint AS payment_method_id,
    g.amount_minor,
    CASE
        WHEN g.currency_r < 0.95 THEN cur.primary_currency
        ELSE (array_remove(
                ARRAY['USD', 'GBP', 'EUR', 'JPY', 'SGD', 'BRL'],
                cur.primary_currency
              ))[1 + floor(g.currency_alt_r * 5)::int]
    END AS currency,
    CASE
        WHEN g.status_r < 0.80 THEN 'captured'
        WHEN g.status_r < 0.88 THEN 'pending'
        WHEN g.status_r < 0.95 THEN 'failed'
        WHEN g.status_r < 0.99 THEN 'refunded'
        ELSE 'disputed'
    END AS status,
    g.created_at,
    CASE
        WHEN g.status_r < 0.80 OR g.status_r >= 0.95
            THEN g.created_at + (1 + floor(g.captured_offset_r * 3)) * interval '1 hour'
        ELSE NULL
    END AS captured_at,
    CASE
        WHEN g.desc_r < 0.05 THEN
            (SELECT string_agg(md5(g.payment_id::text || gs2::text), '')
             FROM generate_series(1, 96) AS gs2)
        ELSE
            'Order payment ' || g.payment_id::text
    END AS description
FROM gen g
JOIN LATERAL (
    SELECT merchant_id FROM merchant_cdf WHERE cum_prob >= g.merchant_r ORDER BY cum_prob LIMIT 1
) mcdf ON true
JOIN merchants m ON m.merchant_id = mcdf.merchant_id
JOIN customer_pm_range cpr ON cpr.customer_id = g.customer_id
CROSS JOIN LATERAL (
    SELECT CASE m.country
        WHEN 'US' THEN 'USD' WHEN 'GB' THEN 'GBP' WHEN 'DE' THEN 'EUR'
        WHEN 'FR' THEN 'EUR' WHEN 'JP' THEN 'JPY' WHEN 'SG' THEN 'SGD'
        WHEN 'BR' THEN 'BRL'
    END AS primary_currency
) cur;

DROP TABLE customer_pm_range;
DROP TABLE merchant_cdf;

-- ---------------------------------------------------------------------
-- ledger_entries: exactly two rows per payment, summing to zero
-- ---------------------------------------------------------------------
-- account_id is derived by the same arithmetic used when accounts were
-- created above, so this needs no join to accounts: merchant accounts
-- have account_id = merchant_id, customer accounts have
-- account_id = merchant_count + customer_id. Debit the customer's
-- account, credit the merchant's account, same magnitude, opposite sign.
INSERT INTO ledger_entries (
    entry_id, payment_id, account_id, direction, amount_minor, currency, posted_date, created_at
)
SELECT
    p.payment_id * 2 - 1 AS entry_id,
    p.payment_id,
    2000::bigint * :scale / 10 + p.customer_id AS account_id,
    'D' AS direction,
    -p.amount_minor AS amount_minor,
    p.currency,
    p.created_at::date AS posted_date,
    p.created_at
FROM payments p
UNION ALL
SELECT
    p.payment_id * 2 AS entry_id,
    p.payment_id,
    p.merchant_id AS account_id,
    'C' AS direction,
    p.amount_minor AS amount_minor,
    p.currency,
    p.created_at::date AS posted_date,
    p.created_at
FROM payments p;

-- ---------------------------------------------------------------------
-- reconcile accounts.balance_minor against the ledger it is a cache of
-- ---------------------------------------------------------------------
-- balance_minor is a CACHE of SUM(amount_minor) over an account's
-- ledger_entries (credits positive, debits negative by construction
-- above) -- see the commented-out CHECK in 00-schema.sql. Day 5's whole
-- lesson is that concurrent transactions can drive that cache out of
-- sync with the ledger; the learner needs to be able to attribute any
-- divergence they observe to their own actions, which means the cache
-- must start EXACTLY consistent with the ledger, not seeded to an
-- unrelated arbitrary positive number.
--
-- OPENING_BALANCE is a FIXED, DOCUMENTED constant -- not a computed
-- headroom -- applied identically to every account, including the
-- platform account (which never receives ledger legs, so its true_balance
-- is 0). This is the invariant Day 5's verify.sh (and any other later
-- check) can assert against, for every account, at seed time:
--   balance_minor - (SUM of that account's ledger_entries.amount_minor) = 100000000000
-- 1e11 minor units is comfortably above any single account's total
-- possible debits at any supported SCALE (the busiest customer account
-- tops out on the order of 1e8-1e9), while leaving vast BIGINT headroom
-- below the ~9.2e18 limit.
\set opening_balance 100000000000
\echo 'accounts opening balance constant (balance_minor - ledger_sum, every account):' :opening_balance

UPDATE accounts a
SET balance_minor = t.true_balance + :opening_balance
FROM (
    SELECT ac.account_id, COALESCE(le.true_balance, 0) AS true_balance
    FROM accounts ac
    LEFT JOIN (
        SELECT account_id, SUM(amount_minor) AS true_balance
        FROM ledger_entries
        GROUP BY account_id
    ) le ON le.account_id = ac.account_id
) t
WHERE a.account_id = t.account_id;

-- ---------------------------------------------------------------------
-- refunds and disputes: derived from payments whose status matches
-- ---------------------------------------------------------------------
INSERT INTO refunds (refund_id, payment_id, amount_minor, reason, created_at)
SELECT
    row_number() OVER (ORDER BY payment_id) AS refund_id,
    payment_id,
    amount_minor,
    (ARRAY['requested_by_customer', 'duplicate', 'fraudulent', 'other'])[1 + floor(random() * 4)::int] AS reason,
    created_at + interval '2 days' AS created_at
FROM payments
WHERE status = 'refunded';

INSERT INTO disputes (dispute_id, payment_id, status, opened_at, resolved_at)
SELECT
    row_number() OVER (ORDER BY payment_id) AS dispute_id,
    payment_id,
    (ARRAY['open', 'won', 'lost'])[1 + floor(random() * 3)::int] AS status,
    created_at + interval '3 days' AS opened_at,
    CASE
        WHEN random() < 0.6
            THEN created_at + interval '3 days' + (1 + floor(random() * 20)) * interval '1 day'
        ELSE NULL
    END AS resolved_at
FROM payments
WHERE status = 'disputed';

-- ---------------------------------------------------------------------
-- wide_payments: denormalised join, Day 2's starting artifact
-- ---------------------------------------------------------------------
INSERT INTO wide_payments (
    row_id, payment_id, amount_minor, currency, status, created_at,
    merchant_id, merchant_name, merchant_country, merchant_risk_tier,
    customer_id, customer_email, customer_country,
    pm_brand, pm_last4, pm_exp_month, pm_exp_year
)
SELECT
    row_number() OVER (ORDER BY p.payment_id) AS row_id,
    p.payment_id, p.amount_minor, p.currency, p.status, p.created_at,
    m.merchant_id, m.name, m.country, m.risk_tier,
    c.customer_id, c.email, c.country,
    pm.brand, pm.last4, pm.exp_month, pm.exp_year
FROM payments p
JOIN merchants m ON m.merchant_id = p.merchant_id
JOIN customers c ON c.customer_id = p.customer_id
JOIN payment_methods pm ON pm.payment_method_id = p.payment_method_id;

-- ---------------------------------------------------------------------
-- wrap up: refresh planner statistics, report row counts
-- ---------------------------------------------------------------------
ANALYZE merchants;
ANALYZE customers;
ANALYZE accounts;
ANALYZE payment_methods;
ANALYZE payments;
ANALYZE ledger_entries;
ANALYZE refunds;
ANALYZE disputes;
ANALYZE wide_payments;

\echo 'merchants:'
SELECT count(*) FROM merchants;
\echo 'customers:'
SELECT count(*) FROM customers;
\echo 'accounts:'
SELECT count(*) FROM accounts;
\echo 'payment_methods:'
SELECT count(*) FROM payment_methods;
\echo 'payments:'
SELECT count(*) FROM payments;
\echo 'ledger_entries:'
SELECT count(*) FROM ledger_entries;
\echo 'refunds:'
SELECT count(*) FROM refunds;
\echo 'disputes:'
SELECT count(*) FROM disputes;
\echo 'wide_payments:'
SELECT count(*) FROM wide_payments;
\echo 'seed generation complete'
