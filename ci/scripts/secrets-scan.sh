#!/usr/bin/env bash
# Fail if detect-secrets finds anything that has not been reviewed.
#
# `detect-secrets audit` is interactive and cannot run in CI, and the
# --fail-on-unaudited flag some guides mention does not exist in 1.5.0. So the
# check is done here: rescan, then require every finding in the baseline to
# carry an explicit `is_secret: false`, meaning a human looked at it.
#
# A newly introduced finding arrives with is_secret unset and fails the build
# until someone reviews it and either fixes the code or records the decision.
set -euo pipefail

cd "$(dirname "$0")/../.."

BASELINE=.secrets.baseline

detect-secrets scan --baseline "$BASELINE"

python3 - "$BASELINE" <<'PY'
import json
import sys

baseline = json.load(open(sys.argv[1]))
unreviewed = [
    f"{path}:{finding['line_number']} ({finding['type']})"
    for path, findings in baseline["results"].items()
    for finding in findings
    if finding.get("is_secret") is not False
]

if unreviewed:
    print("detect-secrets found entries that nobody has reviewed:\n")
    for entry in unreviewed:
        print(f"  {entry}")
    print(
        "\nLook at each one. If it is a real secret, remove it from the code.\n"
        "If it is a false positive, run `detect-secrets audit .secrets.baseline`\n"
        "and mark it, then commit the updated baseline."
    )
    raise SystemExit(1)

total = sum(len(v) for v in baseline["results"].values())
print(f"detect-secrets: {total} finding(s), all reviewed as false positives")
PY
