# Project 1: The First Five Cases

`cases/` — 12 golden-set case files (JSON), each with a `case_id`,
`category`, `expected` verdict/risk, and an `origin` line tracing it to a
real or realistically-modeled failure (never invented for its own sake).

`fixtures/` — the actual diffs each case points its checker at.

The first five, in the order they'd have come off a real ratchet log:
`clean-fix-01/02/03` (easy baseline) and `false-green-01/02` (the failure
mode this whole suite exists to catch). The rest were added while building
Projects 2-8 to round out all 6 categories.
