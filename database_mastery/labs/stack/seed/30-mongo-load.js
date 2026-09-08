// 30-mongo-load.js
//
// mongosh script: deterministically seeds payment_events, merchant_catalog
// and catalog_seed_meta in the `payments` database. Run from inside the
// `ws` service after the PostgreSQL and MySQL stages, e.g.:
//   mongosh "mongodb://mongo:27017/payments?replicaSet=rs0" --quiet --file 30-mongo-load.js
//
// Math.random() cannot be seeded, so determinism comes from a small
// hand-written linear congruential generator (LCG) instead, seeded with a
// fixed constant. Every random draw in this file goes through nextRandom()
// -- never Math.random() -- so two runs at the same SCALE produce
// byte-identical collections.
//
// payment_events is deliberately NOT referentially tied to
// PostgreSQL's payments table: merchant_id and payment_id are drawn
// independently here, so a given event document routinely names a
// merchant that does not actually own that payment_id in PostgreSQL. No
// later lab should attempt to join payment_events to payments expecting
// the merchant_id fields to agree -- that was never the intent of this
// collection, which models an activity stream, not a normalized ledger.

const SCALE = Number(process.env.SCALE || 10);

db = db.getSiblingDB('payments');

// ---------------------------------------------------------------------
// Deterministic PRNG: Numerical Recipes LCG, x[n+1] = (a*x[n] + c) mod m.
// ---------------------------------------------------------------------
let lcgState = 42;
const LCG_A = 1664525;
const LCG_C = 1013904223;
const LCG_M = 4294967296; // 2^32

function nextRandom() {
    lcgState = (LCG_A * lcgState + LCG_C) % LCG_M;
    return lcgState / LCG_M;
}

function randInt(maxExclusive) {
    return Math.floor(nextRandom() * maxExclusive);
}

// ---------------------------------------------------------------------
// Derived counts -- mirror the formulas used in 10-generate.sql so the
// two databases agree on how big "SCALE" makes things.
// ---------------------------------------------------------------------
const MERCHANT_COUNT = Math.floor((2000 * SCALE) / 10);
const PAYMENT_COUNT = Math.floor((5000000 * SCALE) / 10);
const EVENT_COUNT = Math.floor((2000000 * SCALE) / 10);
const BATCH_SIZE = 10000;
const TOP_MERCHANT_COUNT = 20;

print(`SCALE=${SCALE} merchant_count=${MERCHANT_COUNT} event_count=${EVENT_COUNT}`);

// Idempotent re-seed: seed.sh's FORCE=1 path can call this script again.
db.payment_events.drop();
db.merchant_catalog.drop();
db.catalog_seed_meta.drop();

// ---------------------------------------------------------------------
// merchant_id power-law draw: Zipf(s=1) via inverse-CDF, matching
// 10-generate.sql's merchant_cdf exactly (same distribution, same
// reasoning -- see the comment there for the top-1%-gets-44% arithmetic).
// merchant_id doubles as rank: weight(rank) = 1/rank, normalised by the
// harmonic number. Precompute the cumulative distribution once (N is at
// most a few thousand) and binary-search it per draw.
// ---------------------------------------------------------------------
function buildMerchantCdf(n) {
    let h = 0;
    for (let rank = 1; rank <= n; rank++) {
        h += 1 / rank;
    }
    const cdf = new Array(n);
    let cum = 0;
    for (let rank = 1; rank <= n; rank++) {
        cum += (1 / rank) / h;
        cdf[rank - 1] = cum;
    }
    cdf[n - 1] = 2; // catch any draw floating-point rounding lets slip past the real last value
    return cdf;
}

const MERCHANT_CDF = buildMerchantCdf(MERCHANT_COUNT);

function powerLawMerchantId() {
    const r = nextRandom();
    let lo = 0;
    let hi = MERCHANT_CDF.length - 1;
    while (lo < hi) {
        const mid = (lo + hi) >>> 1;
        if (MERCHANT_CDF[mid] >= r) {
            hi = mid;
        } else {
            lo = mid + 1;
        }
    }
    return lo + 1; // merchant_id = rank = index + 1
}

// ---------------------------------------------------------------------
// payment_events
// ---------------------------------------------------------------------
// ts is monotonically increasing across the WHOLE run: tsCursorMs only
// ever advances, independent of batch boundaries, because Day 7's
// hot-shard lesson depends on real time-ordering across the entire
// collection, not only within a batch. The step size is scaled so the
// event stream spans the same ~548-day window as payments.created_at in
// PostgreSQL, regardless of SCALE (EVENT_COUNT and the average step both
// move with SCALE, so their product -- the total span -- does not).
const EVENT_TYPES = ['charge', 'refund', 'payout', 'chargeback', 'webhook_retry'];

const SPAN_DAYS = 548;
const SPAN_MS = SPAN_DAYS * 24 * 60 * 60 * 1000;
const AVG_STEP_MS = Math.max(1, Math.floor(SPAN_MS / EVENT_COUNT));

let tsCursorMs = Date.UTC(2024, 0, 1, 0, 0, 0);

function nextTs() {
    tsCursorMs += 1 + randInt(2 * AVG_STEP_MS); // mean step ~= AVG_STEP_MS, always advances by >= 1ms
    return new Date(tsCursorMs);
}

let inserted = 0;
while (inserted < EVENT_COUNT) {
    const thisBatch = Math.min(BATCH_SIZE, EVENT_COUNT - inserted);
    const docs = [];
    for (let i = 0; i < thisBatch; i++) {
        docs.push({
            payment_id: 1 + randInt(PAYMENT_COUNT),
            merchant_id: powerLawMerchantId(),
            type: EVENT_TYPES[randInt(EVENT_TYPES.length)],
            ts: nextTs(),
            payload: {
                amount_minor: 100 + randInt(999900),
                channel: nextRandom() < 0.5 ? 'api' : 'dashboard'
            }
        });
    }
    // ordered: false lets the batch keep going past a duplicate-key error
    // instead of aborting; it does not change the ts values already fixed
    // into each document above, so monotonicity of the data is unaffected
    // even if the server processes the batch out of array order.
    db.payment_events.insertMany(docs, { ordered: false });
    inserted += thisBatch;
}
print(`payment_events inserted: ${db.payment_events.countDocuments()}`);

// ---------------------------------------------------------------------
// merchant_catalog + catalog_seed_meta
// ---------------------------------------------------------------------
// products is deliberately unbounded (see Global Constraints). The top 20
// merchants -- the whales the power law favors -- get 40,000+ products,
// which puts those documents at several megabytes each: large enough for
// the learner to see the unbounded-array problem approaching the 16 MB
// BSON document limit well before it would ever hit it, which is Day 2's
// cue to restructure before this becomes unusable rather than after it
// breaks.
function buildProducts(count, merchantId) {
    const products = [];
    for (let i = 0; i < count; i++) {
        products.push({
            sku: `SKU-${merchantId}-${i}`,
            name: `Product ${i} for merchant ${merchantId}`,
            description: 'Seeded catalog entry for load-testing document growth.',
            price_minor: 100 + randInt(999900),
            tags: ['seeded', i % 2 === 0 ? 'even' : 'odd']
        });
    }
    return products;
}

const metaDocs = [];
for (let merchantId = 1; merchantId <= MERCHANT_COUNT; merchantId++) {
    const isTop = merchantId <= TOP_MERCHANT_COUNT;
    const productCount = isTop
        ? 40000 + randInt(5000)  // 40,000 - 44,999
        : 20 + randInt(480);     // 20 - 499
    const products = buildProducts(productCount, merchantId);

    // Insert one document at a time here: the top merchants' documents
    // are multi-megabyte, and batching several of those together risks
    // an oversized bulk write message.
    db.merchant_catalog.insertOne({
        merchant_id: merchantId,
        name: `Merchant ${merchantId}`,
        pricing: { currency: 'USD', model: 'per_transaction' },
        products: products
    });

    metaDocs.push({ merchant_id: merchantId, product_count: products.length });
}

// catalog_seed_meta records exactly what was seeded per merchant, as
// {merchant_id, product_count}. Day 2's verify.sh reads this to confirm
// the learner's restructuring of merchant_catalog preserved every
// product -- without it, that check has nothing to compare against.
db.catalog_seed_meta.insertMany(metaDocs, { ordered: false });

print(`merchant_catalog inserted: ${db.merchant_catalog.countDocuments()}`);
print(`catalog_seed_meta inserted: ${db.catalog_seed_meta.countDocuments()}`);

// db.collection.stats() is deprecated as of MongoDB 6.2; $collStats is
// the supported replacement.
const collStats = db.merchant_catalog.aggregate([{ $collStats: { storageStats: {} } }]).toArray()[0];
print(`merchant_catalog avgObjSize: ${collStats.storageStats.avgObjSize}`);
