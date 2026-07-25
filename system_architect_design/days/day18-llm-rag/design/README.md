Put your filled-in 7-step design here (see `reference/design-method.md`).

Today: the RAG document-Q&A pipeline (ingest → chunk → embed → store → retrieve →
prompt → answer → cache). Include the RAG vs fine-tuning vs stuffing vs BM25
tradeoff table, a per-query cost/latency estimate, your chunk-size / top-k / cache
decisions, and the red-team (irrelevant chunks → confident wrong answers; loose
cache; embedding/dimension mismatch).
