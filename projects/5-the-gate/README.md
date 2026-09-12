# Project 5: The Gate

`.github/workflows/eval-gate.yml` — runs the full golden set on any PR that
touches the checker's own rules/cases/runner, and fails the build if a
category or the overall rate drops below its bar.

`bars.json` — the minimum pass rate per category, and *why* (the bar is a
decision, not a discovery).

`baseline.json` — the committed reference the gate compares new runs
against, so a silent regression can't merge.
