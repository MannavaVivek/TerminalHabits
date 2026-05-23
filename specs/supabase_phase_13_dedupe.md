# Phase 13 — Supabase dedupe (one-off)

During Phase 12 testing, the autoincrement-id mismatch between devices (Mac and
Android each assign their own IDs from independent sequences) caused duplicate
`(user_id, habit_id, day)` rows to accumulate on the server. The client now
handles them at sync time (see `pullAll` / `_upsertLocalRow` for completions),
but the server-side rows should be deduped once.

## Run once in Supabase SQL editor

```sql
-- Keep the most-recently-updated row per (user_id, habit_id, day) tuple;
-- delete the rest. Tie-breaks on id desc.
DELETE FROM completions
WHERE id IN (
  SELECT id FROM (
    SELECT
      id,
      ROW_NUMBER() OVER (
        PARTITION BY user_id, habit_id, day
        ORDER BY updated_at DESC NULLS LAST, id DESC
      ) AS rn
    FROM completions
  ) ranked
  WHERE rn > 1
);
```

After running, verify with:

```sql
SELECT user_id, habit_id, day, COUNT(*) AS n
FROM completions
GROUP BY user_id, habit_id, day
HAVING COUNT(*) > 1;
```

Expected: zero rows.

## Optional follow-up — add the constraint

A unique index on `(user_id, habit_id, day)` would prevent future duplicates
**at the cost** of pushes failing when two devices race a new completion. We
chose not to add this because the client's LWW resolution at pull time is
already idempotent — duplicates are tolerated and pruned automatically once
seen. If you want the index anyway:

```sql
CREATE UNIQUE INDEX completions_user_habit_day_uniq
  ON completions (user_id, habit_id, day);
```

This will fail to create if any duplicates remain, so run the DELETE above
first.
