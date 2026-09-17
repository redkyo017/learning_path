# Task 3: Failure Catalog Pattern Fixes

## Summary
Fixed two grep patterns in `failure_catalog.md` to match patterns defined in `main.go`.

## Changes Made

### 1. JWT_EXPIRED Pattern (Line 27)
- **Before:** `JWT expired\|token expired\|exp claim`
- **After:** `JWT expired\|token expired\|\bexp\b claim`
- **Reason:** Added word boundaries (`\b`) around "exp" to match main.go line 35 and prevent false matches like "expected" or "exponent"

### 2. EVENT_SYNC_LAG Pattern (Line 29)
- **Before:** `eventHub.*error\|sync lag\|event sync`
- **After:** `eventHub.*error\|sync lag\|event sync.*fail`
- **Reason:** Added `.*fail` suffix to match main.go line 37 and narrow scope to actual sync failures

## Verification
✓ Markdown syntax valid (table format correct, no syntax errors)
✓ Patterns now match main.go reference implementation
✓ Both patterns are more precise and reduce false positives

## Status: **FIXED**

File: `/Users/hunghan/han_git/docker-tools/github-sandbox/repos/learning_path/wso2_mastery/labs/phase4/day52/failure_catalog.md`
