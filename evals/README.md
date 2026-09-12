# Trusting the Checker — Eval Suite

This is a working implementation of the 8 capstone projects from the
"Trusting the Checker" crash course. It evaluates **the checker** — a code
reviewer agent (defined in `reviewer-prompt.md`) that looks at a diff and
decides PASS/FAIL + risk level. We are not testing the code being reviewed;
we are testing whether the *reviewer itself* can be trusted.

## Layout

```
evals/
  reviewer-prompt.md   # the checker under test (system prompt)
  judge-prompt.md       # the LLM judge used for qualitative grading
  rubric.md             # Project 3: anchored rubric
  bars.json             # minimum pass rate per category (the decision)
  cases/                # Project 1 + 7: golden set case files (JSON)
  fixtures/             # the diffs each case points at
  run.sh                # Project 2: the runner
  lib/grade.sh           # grading helpers used by run.sh
  results/               # per-run output (gitignored except baseline.json)
  baseline.json          # Project 5/6: committed regression baseline
  calibration/           # Project 4: grade-the-grader protocol + data
  holdouts/              # Project 8: sealed cases, never tuned against
  night-watch/           # Project 6: nightly drift-watch notes
.github/workflows/eval-gate.yml   # Project 5: the gate (CI)
```

## Quick start

```bash
# run the whole visible golden set, 3 runs per case (default)
bash evals/run.sh

# run just one category
bash evals/run.sh --category injection

# run with the LLM judge doing qualitative grading too (slower, costs more)
bash evals/run.sh --judge

# run the sealed hold-out set (do this rarely — see holdouts/README.md)
bash evals/run.sh --holdouts
```

Each case is a JSON file with an `origin` line tracing it to a real (or
realistically modeled) failure — never invented for its own sake except the
deliberately "easy" baseline cases, which are labeled as such.
