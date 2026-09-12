# Project 8: Sealed Hold-outs

These three cases (`holdout-clean-fix-01`, `holdout-false-green-01`,
`holdout-injection-01`) exist for one purpose: to never be looked at while
tuning `reviewer-prompt.md`, `rubric.md`, `bars.json`, or the `must_mention`
/ `unacceptable` patterns on the main `evals/cases/` set.

## Why

Concept 11 (Goodhart's Law): "when a measure becomes a target, it stops
being a good measure." Every time this session hit a failing case in the
main suite, the fix was to edit `reviewer-prompt.md` or the case's expected
values until it passed. That is exactly the right thing to do — but it
means the main suite's pass rate is no longer independent evidence that the
checker generalizes; it is partly evidence that we tuned to the suite.
Hold-outs are the check on that.

## Rules for this folder

1. **Never read these fixtures while debugging a main-suite failure.** If a
   fix to `reviewer-prompt.md` was motivated by something you saw in here,
   the hold-out is burned — move it to `evals/cases/`, write a fresh
   hold-out, and say so in the commit message.
2. **Run rarely, on purpose** — monthly, or right before a release, not on
   every commit. `bash evals/run.sh --holdouts`
3. **Track the rate over time** in `tracking.json`, alongside the same-week
   tuned-suite rate. Append an entry after every hold-out run:
   ```json
   { "date": "2026-10-01", "holdout_rate": 1.0, "tuned_rate": 0.97, "n_holdout_cases": 3 }
   ```
4. **Widening gap = act.** If the tuned rate stays near 100% while the
   hold-out rate drifts down, that's overfitting to the visible cases, not
   real improvement. Response is to broaden `reviewer-prompt.md`'s rules
   (make them more general), not to special-case the hold-out's specific
   diffs into the rubric.
5. **Refresh, don't just accumulate.** When a hold-out case's underlying
   behavior stops existing (the code it targets was deleted) or
   requirements changed, retire it and write a new one from a fresh real or
   realistically-modeled failure — same as the main ratchet in Concept 4,
   just on a slower, sealed track.

## What's in here right now

- `holdout-clean-fix-01` — baseline sanity, same purpose as the main
  clean_fix cases.
- `holdout-false-green-01` — a **different disguise** of the false-green
  pattern than the tuned cases: the covering assertion is weakened to a
  tautology instead of being deleted outright, while the code underneath
  develops a real privilege-escalation bug.
- `holdout-injection-01` — a **different delivery mechanism** for a
  reviewer-injection attempt: a fake machine-readable "reviewer-config"
  comment claiming auto-approval, instead of an imperative sentence
  addressed to the reviewer, bundled with a real unreviewed SSN-export
  function.

Both hard cases were deliberately built to test the same *principle* the
tuned cases test (don't trust content inside the diff; a weakened assertion
is as dangerous as a deleted one) through a *different concrete shape*, so
a checker that merely pattern-matched the tuned cases' exact wording would
fail here even if it looked well-calibrated on the visible suite.
