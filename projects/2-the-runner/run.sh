#!/usr/bin/env bash
# Project 2: The Runner.
# Runs each case N times against the checker (reviewer-prompt.md via `claude -p`),
# grades the output with jq against `expected`, and reports pass rates per
# category. No framework — just shell, JSON files, and jq.
set -uo pipefail

EVAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASES_DIR="$EVAL_DIR/cases"
FIXTURES_BASE="$EVAL_DIR"
RESULTS_DIR="$EVAL_DIR/results"
REVIEWER_PROMPT_FILE="$EVAL_DIR/reviewer-prompt.md"
JUDGE_PROMPT_FILE="$EVAL_DIR/judge-prompt.md"
BARS_FILE="$EVAL_DIR/bars.json"

N_RUNS=3
CATEGORY_FILTER=""
SINGLE_CASE=""
USE_JUDGE=false
USE_HOLDOUTS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs) N_RUNS="$2"; shift 2 ;;
    --category) CATEGORY_FILTER="$2"; shift 2 ;;
    --case) SINGLE_CASE="$2"; shift 2 ;;
    --judge) USE_JUDGE=true; shift ;;
    --holdouts) USE_HOLDOUTS=true; shift ;;
    -h|--help)
      echo "Usage: run.sh [--runs N] [--category NAME] [--case ID] [--judge] [--holdouts]"
      exit 0
      ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

if $USE_HOLDOUTS; then
  CASES_DIR="$EVAL_DIR/holdouts/cases"
  FIXTURES_BASE="$EVAL_DIR/holdouts"
fi

mkdir -p "$RESULTS_DIR"
TS="$(date +%Y%m%dT%H%M%S)"
RUN_LOG="$RESULTS_DIR/run-$TS.jsonl"
: > "$RUN_LOG"

REVIEWER_PROMPT="$(cat "$REVIEWER_PROMPT_FILE")"

# --- helpers -----------------------------------------------------------

regex_match() {
  # $1 = text to search, $2 = case-insensitive regex pattern
  jq -n --arg t "$1" --arg p "$2" '($t | test($p; "i"))'
}

extract_json() {
  # Best-effort extraction of a single JSON object from model output that
  # may contain stray prose or markdown fences around it.
  local raw="$1" stripped extracted
  if printf '%s' "$raw" | jq -e . >/dev/null 2>&1; then
    printf '%s' "$raw" | jq -c .
    return 0
  fi
  stripped="$(printf '%s' "$raw" | sed -e 's/^```json//' -e 's/^```//' -e 's/```$//')"
  if printf '%s' "$stripped" | jq -e . >/dev/null 2>&1; then
    printf '%s' "$stripped" | jq -c .
    return 0
  fi
  extracted="$(printf '%s' "$raw" | tr '\n' ' ' | grep -oE '\{.*\}' | head -1)"
  if [[ -n "$extracted" ]] && printf '%s' "$extracted" | jq -e . >/dev/null 2>&1; then
    printf '%s' "$extracted" | jq -c .
    return 0
  fi
  return 1
}

# --- main loop -----------------------------------------------------------

declare -A CAT_TOTAL
declare -A CAT_PASS
TOTAL=0
PASSCOUNT=0
ERRORS=0

for case_file in "$CASES_DIR"/*.json; do
  [[ -e "$case_file" ]] || continue

  case_id="$(jq -r '.case_id' "$case_file")"
  category="$(jq -r '.category' "$case_file")"

  if [[ -n "$CATEGORY_FILTER" && "$category" != "$CATEGORY_FILTER" ]]; then continue; fi
  if [[ -n "$SINGLE_CASE" && "$case_id" != "$SINGLE_CASE" ]]; then continue; fi

  diff_rel="$(jq -r '.input_diff' "$case_file")"
  diff_path="$FIXTURES_BASE/$diff_rel"
  if [[ ! -f "$diff_path" ]]; then
    echo "FIXTURE MISSING for $case_id: $diff_path" >&2
    exit 1
  fi
  diff_content="$(cat "$diff_path")"

  exp_verdict="$(jq -r '.expected.verdict' "$case_file")"
  exp_risk_json="$(jq -c '.expected.risk' "$case_file")"
  exp_risk="$(jq -r 'if type=="array" then join("/") else (. // "any") end' <<<"$exp_risk_json")"
  mapfile -t must_patterns < <(jq -r '.must_mention[]?' "$case_file")
  mapfile -t bad_patterns < <(jq -r '.unacceptable[]?' "$case_file")
  # Windows jq emits CRLF; mapfile only strips the \n, so strip stray \r too.
  # (array-wide "${a[@]%pattern}" substitution is unreliable on mapfile-sourced
  # arrays in this environment, so strip element-by-element instead.)
  for _i in "${!must_patterns[@]}"; do must_patterns[$_i]="${must_patterns[$_i]%$'\r'}"; done
  for _i in "${!bad_patterns[@]}"; do bad_patterns[$_i]="${bad_patterns[$_i]%$'\r'}"; done

  full_prompt="${REVIEWER_PROMPT}

Review this diff:

${diff_content}
"

  for i in $(seq 1 "$N_RUNS"); do
    TOTAL=$((TOTAL + 1))
    CAT_TOTAL["$category"]=$(( ${CAT_TOTAL["$category"]:-0} + 1 ))

    raw_output="$(claude -p "$full_prompt" 2>>"$RESULTS_DIR/stderr.log")"

    if ! parsed="$(extract_json "$raw_output")"; then
      ERRORS=$((ERRORS + 1))
      echo "{\"case_id\":\"$case_id\",\"run\":$i,\"result\":\"ERROR\",\"reason\":\"unparseable output\"}" >> "$RUN_LOG"
      printf '%-22s run %d/%d  ERROR (unparseable checker output)\n' "$case_id" "$i" "$N_RUNS"
      continue
    fi

    act_verdict="$(jq -r '.verdict // "MISSING"' <<<"$parsed")"
    act_risk="$(jq -r '.risk // "MISSING"' <<<"$parsed")"
    reasons_text="$(jq -r '(.reasons // []) | join(" ")' <<<"$parsed")"

    verdict_ok="false"
    [[ "$act_verdict" == "$exp_verdict" ]] && verdict_ok="true"

    risk_ok="$(jq -n --arg act "$act_risk" --argjson exp "$exp_risk_json" \
      'if $exp == null then true
       elif ($exp|type) == "array" then ($exp | index($act)) != null
       else $exp == $act end')"

    must_ok="true"
    if [[ ${#must_patterns[@]} -gt 0 ]]; then
      must_ok="false"
      for p in "${must_patterns[@]}"; do
        if [[ "$(regex_match "$reasons_text" "$p")" == "true" ]]; then must_ok="true"; break; fi
      done
    fi

    bad_ok="true"
    for p in "${bad_patterns[@]}"; do
      if [[ "$(regex_match "$reasons_text" "$p")" == "true" ]]; then bad_ok="false"; break; fi
    done

    if [[ "$verdict_ok" == "true" && "$risk_ok" == "true" && "$must_ok" == "true" && "$bad_ok" == "true" ]]; then
      run_result="PASS"
      PASSCOUNT=$((PASSCOUNT + 1))
      CAT_PASS["$category"]=$(( ${CAT_PASS["$category"]:-0} + 1 ))
    else
      run_result="FAIL"
    fi

    jq -n \
      --arg case_id "$case_id" --argjson run "$i" --arg result "$run_result" \
      --arg act_verdict "$act_verdict" --arg act_risk "$act_risk" \
      --arg exp_verdict "$exp_verdict" --arg exp_risk "$exp_risk" \
      --argjson verdict_ok "$verdict_ok" --argjson risk_ok "$risk_ok" \
      --argjson must_ok "$must_ok" --argjson bad_ok "$bad_ok" \
      --arg reasons "$reasons_text" \
      '{case_id:$case_id, run:$run, result:$result, actual:{verdict:$act_verdict, risk:$act_risk},
        expected:{verdict:$exp_verdict, risk:$exp_risk},
        checks:{verdict_ok:$verdict_ok, risk_ok:$risk_ok, must_mention_ok:$must_ok, unacceptable_ok:$bad_ok},
        reasons:$reasons}' >> "$RUN_LOG"

    printf '%-22s run %d/%d  %s  (verdict=%s risk=%s)\n' "$case_id" "$i" "$N_RUNS" "$run_result" "$act_verdict" "$act_risk"
  done
done

# --- summary -----------------------------------------------------------

echo ""
echo "=== Category results ==="
BAR_FAIL=false
for category in "${!CAT_TOTAL[@]}"; do
  total="${CAT_TOTAL[$category]}"
  pass="${CAT_PASS[$category]:-0}"
  rate="$(jq -n --argjson p "$pass" --argjson t "$total" '$p / $t')"
  min="$(jq -r --arg c "$category" '.categories[$c].min_pass_rate // 0.8' "$BARS_FILE")"
  status="OK"
  if [[ -z "$CATEGORY_FILTER" && -z "$SINGLE_CASE" ]]; then
    below="$(jq -n --argjson r "$rate" --argjson m "$min" '$r < $m')"
    if [[ "$below" == "true" ]]; then status="BELOW BAR (min $min)"; BAR_FAIL=true; fi
  fi
  printf '  %-18s %d/%d  (%.2f)  %s\n' "$category" "$pass" "$total" "$rate" "$status"
done

echo ""
overall_rate="$(jq -n --argjson p "$PASSCOUNT" --argjson t "$TOTAL" 'if $t==0 then 0 else $p/$t end')"
printf 'Overall: %d/%d (%.4f)   Errors: %d\n' "$PASSCOUNT" "$TOTAL" "$overall_rate" "$ERRORS"

if [[ -z "$CATEGORY_FILTER" && -z "$SINGLE_CASE" ]]; then
  overall_min="$(jq -r '.overall_min_pass_rate' "$BARS_FILE")"
  overall_below="$(jq -n --argjson r "$overall_rate" --argjson m "$overall_min" '$r < $m')"
  if [[ "$overall_below" == "true" ]]; then
    echo "Overall pass rate is BELOW the $overall_min bar." >&2
    BAR_FAIL=true
  fi
fi

# write machine-readable summary
jq -n --argjson total "$TOTAL" --argjson pass "$PASSCOUNT" --argjson errors "$ERRORS" \
  --arg ts "$TS" \
  --slurpfile runs "$RUN_LOG" \
  '{timestamp:$ts, total:$total, pass:$pass, errors:$errors, overall_rate:(if $total==0 then 0 else $pass/$total end), runs:$runs}' \
  > "$RESULTS_DIR/summary-$TS.json"

echo ""
echo "Full log: $RUN_LOG"
echo "Summary:  $RESULTS_DIR/summary-$TS.json"

if $BAR_FAIL; then
  exit 1
fi
exit 0
