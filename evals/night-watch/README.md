# Project 6: The Night Watch

Purpose (Concept 9 — Drift): the model underneath THE CHECKER can change
behavior with zero local code change (a provider-side model update). The
only way to notice is to keep re-running the same golden set on a clock and
watch for the rate to move, not to wait for a human to notice something
felt off.

## What runs nightly

```
bash evals/run.sh --runs 3
```

full golden set, three runs per case, same command a human would run by
hand for Project 2. The nightly job is not special-cased — it is the exact
same gate as CI (Project 5), just on a timer instead of on a PR diff, so
"nightly" and "on every relevant PR" never drift apart into two different
definitions of passing.

## Alerting rule

- Compare the new run's `overall_rate` (in
  `evals/results/summary-*.json`) against `evals/baseline.json`.
- **Silence = baseline maintained.** Only page/notify when a category or
  the overall rate drops below its bar in `evals/bars.json`, or drops more
  than 5 points below the committed baseline (same threshold as the CI
  gate in `.github/workflows/eval-gate.yml`).
- When it fires: **re-run before panicking** (Concept 10) — three runs per
  case is a rough smoke signal with real sampling noise. If a second full
  run confirms the drop, that's when to open an issue, not on the first
  alert.
- Read *which* cases dropped before deciding how urgent this is. A dip
  concentrated in `style_churn` is very different from a dip in
  `false_green` or `injection` (both zero-tolerance categories per
  `bars.json`).
- If the drop coincides with a known model version bump, re-run the
  Project-4 calibration (`evals/calibration/run_calibration.sh`) before
  trusting any new scores that come out of the judge — the judge itself may
  need re-anchoring against the same model update.

## Scheduling

This runs as a scheduled cloud agent (see the project's cron entry —
created with the `schedule` skill / `CronCreate`, not a GitHub Actions
`schedule:` trigger, so it runs independently of any PR activity and keeps
watching even when nobody is actively working on the checker). Its prompt
is:

> Run `bash evals/run.sh --runs 3` in the Trusting-the-Checker project.
> Compare the resulting `overall_rate` and per-category rates against
> `evals/baseline.json` and `evals/bars.json`. If everything is at or above
> bar, reply with a one-line "nightly watch: nominal" summary and do
> nothing else. If anything is below bar, re-run once to rule out noise,
> then report exactly which case(s)/categories dropped, with the actual
> reasoning text from the failing runs, and do NOT modify
> `reviewer-prompt.md`, `rubric.md`, or any case's `expected` values without
> the user's say-so — flag it, don't self-heal it.

The "don't self-heal it" instruction matters: this course's own rubric was
patched multiple times *during development* based on miscalibrated
expectations, and that's the right move for a human building the suite —
but a nightly job silently loosening the bar every time it sees a red run
would defeat the entire point of the night watch.
