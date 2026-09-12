# Project 2: The Runner

`run.sh` — no framework, just shell + `jq`. For each case: reads the
fixture diff, sends it to the checker via `claude -p`, parses the JSON
verdict back out, and grades it against the case's `expected` value with
`jq` (not by asking another model to read prose).

To actually run it, it needs the sibling `cases/`, `fixtures/`,
`reviewer-prompt.md`, and `bars.json` from the real `evals/` folder — see
`../README.md`.

Usage: `bash run.sh [--runs N] [--category NAME] [--case ID] [--judge] [--holdouts]`
