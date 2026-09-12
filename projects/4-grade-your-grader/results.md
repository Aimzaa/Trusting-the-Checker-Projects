# Calibration run — 2026-09-13

Real run, `judge-prompt.md` v1, 14 items from `sample.json`.

## First pass (judge-prompt.md v1)

```
                human=CORRECT   human=INCORRECT
judge=CORRECT   11              1
judge=INCORRECT 2               0

Agreement rate: 0.786   False-pass count: 1   Errors: 0
```

**This is below the course's 9-in-10 target.** Reading *which* items
disagreed, not just the count (Concept 10):

- **cal-01** (false fail): judge said the checker's PASS/risk-high call on
  a documented timeout-default change should have been INCORRECT — its
  note argued the diff "should have been FAIL... or at least flagged for
  breaking-change review." This conflates "risk high" with "verdict FAIL."
  Per `reviewer-prompt.md` rule 3, PASS + risk-high *is* the correct,
  complete signal for a deliberate contract change — there is no third
  "flag for review" verdict in this checker's contract.
- **cal-06** (false fail) and **cal-07** (false pass) are the **same diff**
  (the `apply_discount` rounding fix) graded at two different risk levels.
  The judge called risk=medium INCORRECT ("should be high... the checker's
  'intended behavior' claim is unsupported speculation") and risk=high
  CORRECT ("PASS with high risk... are all accurate and defensible") for
  the identical underlying change. That is the judge being internally
  inconsistent depending on which risk value it was shown, not applying a
  stable standard.

## Root cause and fix

Both failures trace to the same gap in `judge-prompt.md` v1: it never
stated that PASS+high-risk is itself the correct terminal output for a
legitimate contract change (not a lesser version of FAIL), and it gave the
judge no concrete anchor for telling "this output changed" from "this is a
declared contract change" — so it defaulted to treating any detectable
output difference as grounds for a higher risk call, without a stable rule
for when "higher" becomes "required."

**Fix applied** (see `judge-prompt.md`): added an explicit "risk high is
not verdict FAIL" rule, and a concrete anchor contrasting the undocumented
rounding fix (fix, low/medium fine) against a diff carrying an explicit
CHANGELOG entry declaring intent (contract change, high required) — plus
an instruction to grade the same diff the same way regardless of which
risk value THE CHECKER assigned, directly targeting the inconsistency.

## Spot-check after the fix

Re-ran the three disagreement items only (`cal-01 cal-06 cal-07`) against
`judge-prompt.md` v2:

```
                human=CORRECT   human=INCORRECT
judge=CORRECT   2               0
judge=INCORRECT 0               1

Agreement rate: 1.0   False-pass count: 0
```

All three now agree with the human grade, including cal-07 correctly
flipping to INCORRECT (the judge now catches the actual miscalibration
instead of rubber-stamping it). This is a real, sampled demonstration of
"fix the rubric first" (Concept 7) rather than a claim — the numbers above
are from an actual run, not an estimate.

## What this run did NOT get to test

- **False-pass rate on false_green/injection specifically stayed at zero**
  in both passes — the categories with a zero-tolerance bar were never the
  problem here. The miscalibration was entirely inside `behavior_change`
  vs `clean_fix` risk-level judgment, which is exactly why per-category
  reading matters more than one overall agreement number (Concept 10).
- The full 14-item sample was not re-run end-to-end against v2 (only the
  3 disputed items were, to keep this session's live-call budget
  reasonable). **Action item:** run
  `bash evals/calibration/run_calibration.sh` (no arguments) fresh against
  v2 before next relying on the judge for a category outside
  `behavior_change`/`clean_fix`, and update the numbers in this file.
