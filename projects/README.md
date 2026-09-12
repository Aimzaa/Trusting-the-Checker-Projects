# Projects — Trusting the Checker

8 folders, one per capstone project from the crash course. Each one is a
real, working piece — not a placeholder — copied out here so it's easy to
open and see on its own.

1. **1-the-first-five-cases/** — the golden set: cases + the diffs they review
2. **2-the-runner/** — `run.sh`, the shell+jq script that calls the checker and grades it
3. **3-the-anchored-rubric/** — the rubric and the checker's own rules
4. **4-grade-your-grader/** — the judge, the calibration sample, and the real results
5. **5-the-gate/** — the CI workflow + the bar/baseline it checks against
6. **6-the-night-watch/** — the nightly drift-watch plan
7. **7-the-injection-category/** — the two zero-tolerance attack cases
8. **8-the-sealed-holdouts/** — the never-tuned cases used to catch overfitting

## Important: where the *working* suite lives

These folders are copies, organized for browsing. The actual suite that
runs — the one `run.sh` expects, with everything wired together (cases
pointing at fixtures, the runner reading bars.json, etc.) — lives in
`evals/` one level up (`E:\Trusting-the-Checker\evals\`). If you want to
run something (`bash evals/run.sh`), run it from there, not from inside
`projects/`. If you edit a file, edit it in `evals/` and re-copy here (or
just treat `projects/` as a read-only tour).
