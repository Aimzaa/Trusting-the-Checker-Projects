# Project 4: Grade the Grader

Four-step protocol (Concept 7) to measure whether `judge-prompt.md` (the
LLM judge that semantically grades THE CHECKER's reasoning) can be trusted,
by comparing it blind against independent human judgment.

## The four steps, as implemented here

1. **Sample deliberately.** `sample.json` holds 14 real transcripts pulled
   from this suite's own `evals/results/*.jsonl` logs — not invented. It
   deliberately includes two historically-miscalibrated transcripts
   (`cal-03`, `cal-07`) alongside clean passes, per the course's "include
   FAILs and borderline work, not just easy PASSes."
2. **Grade blind.** `answer_key.json` holds human grades written against
   `rubric.md`'s fact-check questions, kept in a separate file so the judge
   run (`run_calibration.sh`) never reads it.
3. **Compare in a four-cell table.** `run_calibration.sh` runs the judge on
   every item in `sample.json` and cross-tabs its CORRECT/INCORRECT call
   against `answer_key.json`:
   - **correct pass** — judge and human both say the checker did well
   - **false fail** — judge says INCORRECT, human says the checker was fine
     (judge too strict)
   - **false pass** — judge says CORRECT, human says the checker was wrong
     (judge too lenient — the dangerous cell)
   - **correct fail** — judge and human both say the checker got it wrong
4. **Fix the rubric first.** See `results.md` for what this run actually
   found and what was changed in `judge-prompt.md` as a result, before any
   thought of swapping the judge model.

## Running it

```bash
bash evals/calibration/run_calibration.sh          # full 14-item sample
bash evals/calibration/run_calibration.sh cal-01 cal-07   # just some items
```

## Re-calibrate when

- `judge-prompt.md` or `rubric.md` changes
- the underlying model updates (Concept 9 — drift affects the judge too,
  not just the checker)
- the false-pass count is ever nonzero on a `false_green` or `injection`
  item specifically (zero-tolerance categories per `evals/bars.json`)

## Growing the sample over time

14 items is a starting point, not a ceiling. Every time a real checker
miscalibration is caught and fixed (via the ratchet described in
`rubric.md`'s anchors), add that transcript to `sample.json` with an
honest human grade in `answer_key.json` — the same way the main golden set
in `evals/cases/` grows. Target 20+ over time, per the course.
