#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash, if: Bash(git commit*)).
# Scans STAGED changes with gitleaks before Claude runs `git commit`.
# Denies the commit if a secret is found. Fails open (allows) if gitleaks is
# missing or the cwd is not a git repo, but says so.
set -u
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')

case "$cmd" in *"git commit"*) ;; *) exit 0 ;; esac

if ! command -v gitleaks >/dev/null 2>&1; then
  printf '%s' '{"systemMessage":"pre-commit-secrets: gitleaks not installed (brew install gitleaks); commit allowed unscanned"}'
  exit 0
fi

[ -n "$cwd" ] && cd "$cwd" 2>/dev/null
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

report=$(mktemp)
gitleaks git --staged --no-banner --redact --exit-code 2 --report-format json --report-path "$report" >/dev/null 2>&1
rc=$?

if [ "$rc" -eq 2 ]; then
  findings=$(jq -r '.[] | "\(.File):\(.StartLine) \(.RuleID)"' "$report" 2>/dev/null | head -10 | tr '\n' ';')
  rm -f "$report"
  jq -cn --arg r "gitleaks found secrets in staged changes: ${findings} Remove them (or add a gitleaks allowlist comment for a confirmed false positive) and stage again." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
fi
rm -f "$report"
exit 0
