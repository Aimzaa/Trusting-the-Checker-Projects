#!/usr/bin/env bash
# Project 4: Grade the Grader.
# Runs THE JUDGE blind over calibration/sample.json (no ground truth shown),
# then compares the judge's CORRECT/INCORRECT calls to the human blind
# grades in answer_key.json, producing the four-cell table from Concept 7.
set -uo pipefail

CAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVAL_DIR="$(dirname "$CAL_DIR")"
JUDGE_PROMPT="$(cat "$EVAL_DIR/judge-prompt.md")"
SAMPLE_FILE="$CAL_DIR/sample.json"
ANSWER_FILE="$CAL_DIR/answer_key.json"
OUT_FILE="$CAL_DIR/judge_results.jsonl"
: > "$OUT_FILE"

extract_json() {
  local raw="$1" stripped extracted
  if printf '%s' "$raw" | jq -e . >/dev/null 2>&1; then printf '%s' "$raw" | jq -c .; return 0; fi
  stripped="$(printf '%s' "$raw" | sed -e 's/^```json//' -e 's/^```//' -e 's/```$//')"
  if printf '%s' "$stripped" | jq -e . >/dev/null 2>&1; then printf '%s' "$stripped" | jq -c .; return 0; fi
  extracted="$(printf '%s' "$raw" | tr '\n' ' ' | grep -oE '\{.*\}' | head -1)"
  if [[ -n "$extracted" ]] && printf '%s' "$extracted" | jq -e . >/dev/null 2>&1; then printf '%s' "$extracted" | jq -c .; return 0; fi
  return 1
}

if [[ $# -gt 0 ]]; then
  ITEM_IDS=("$@")
else
  mapfile -t ITEM_IDS < <(jq -r '.items[].item_id' "$SAMPLE_FILE")
  for _i in "${!ITEM_IDS[@]}"; do ITEM_IDS[$_i]="${ITEM_IDS[$_i]%$'\r'}"; done
fi

correct_pass=0   # judge=CORRECT, human=CORRECT
false_fail=0     # judge=INCORRECT, human=CORRECT   (judge too strict)
false_pass=0     # judge=CORRECT, human=INCORRECT   (judge too lenient - dangerous)
correct_fail=0   # judge=INCORRECT, human=INCORRECT
errors=0

for item_id in "${ITEM_IDS[@]}"; do
  item="$(jq -c --arg id "$item_id" '.items[] | select(.item_id==$id)' "$SAMPLE_FILE")"
  diff_rel="$(jq -r '.input_diff' <<<"$item")"
  diff_path="$CAL_DIR/$diff_rel"
  diff_content="$(cat "$diff_path")"
  checker_output="$(jq -c '.checker_output' <<<"$item")"

  prompt="${JUDGE_PROMPT}

The diff under review:

${diff_content}

THE CHECKER's output for this diff:

${checker_output}
"

  raw="$(claude -p "$prompt" 2>>"$CAL_DIR/stderr.log")"
  if ! judge_parsed="$(extract_json "$raw")"; then
    errors=$((errors + 1))
    echo "{\"item_id\":\"$item_id\",\"error\":\"unparseable\"}" >> "$OUT_FILE"
    printf '%-10s ERROR (unparseable judge output)\n' "$item_id"
    continue
  fi

  judge_grade="$(jq -r '.grade // "MISSING"' <<<"$judge_parsed")"
  human_grade="$(jq -r --arg id "$item_id" '.grades[$id].human_grade' "$ANSWER_FILE")"

  cell="?"
  if [[ "$judge_grade" == "CORRECT" && "$human_grade" == "CORRECT" ]]; then cell="correct_pass"; correct_pass=$((correct_pass+1));
  elif [[ "$judge_grade" == "INCORRECT" && "$human_grade" == "CORRECT" ]]; then cell="false_fail"; false_fail=$((false_fail+1));
  elif [[ "$judge_grade" == "CORRECT" && "$human_grade" == "INCORRECT" ]]; then cell="false_pass"; false_pass=$((false_pass+1));
  elif [[ "$judge_grade" == "INCORRECT" && "$human_grade" == "INCORRECT" ]]; then cell="correct_fail"; correct_fail=$((correct_fail+1));
  fi

  jq -n --arg item_id "$item_id" --arg judge "$judge_grade" --arg human "$human_grade" --arg cell "$cell" --arg note "$(jq -r '.note' <<<"$judge_parsed")" \
    '{item_id:$item_id, judge:$judge, human:$human, cell:$cell, judge_note:$note}' >> "$OUT_FILE"

  printf '%-10s judge=%-10s human=%-10s -> %s\n' "$item_id" "$judge_grade" "$human_grade" "$cell"
done

total=$((correct_pass + false_fail + false_pass + correct_fail))
agreement="0"
if [[ $total -gt 0 ]]; then
  agreement="$(jq -n --argjson a "$correct_pass" --argjson b "$correct_fail" --argjson t "$total" '(($a+$b)/$t)')"
fi

echo ""
echo "=== Four-cell table ==="
printf '                human=CORRECT   human=INCORRECT\n'
printf 'judge=CORRECT   %-15d %-15d\n' "$correct_pass" "$false_pass"
printf 'judge=INCORRECT %-15d %-15d\n' "$false_fail" "$correct_fail"
echo ""
printf 'Agreement rate: %s   False-pass count: %d   Errors: %d\n' "$agreement" "$false_pass" "$errors"
echo "Per-item results: $OUT_FILE"
