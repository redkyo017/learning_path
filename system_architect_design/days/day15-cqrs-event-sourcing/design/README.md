Put your filled-in 7-step design here (see `reference/design-method.md`). Today:
the Order aggregate's events (Placed/Paid/Shipped/Cancelled), the fold function, the
`order_status_view` read model, and a snapshot policy — with a tradeoff table
(CRUD vs CQRS vs event sourcing) and a self-red-team (projection lag, non-deterministic
fold, read-model bug).
