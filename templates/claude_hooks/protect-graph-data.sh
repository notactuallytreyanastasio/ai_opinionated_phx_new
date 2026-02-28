#!/bin/bash
# Protect graph data files from mixed commits.
# docs/git-history.json and docs/graph-data.json must never be in a commit
# alongside other files. They can only be committed when they are the ONLY
# staged files.

# Only intercept git commit commands
if ! echo "$CLAUDE_TOOL_INPUT" | grep -q "git commit"; then
  exit 0
fi

STAGED=$(git diff --cached --name-only 2>/dev/null)
[ -z "$STAGED" ] && exit 0

HAS_GRAPH=false
HAS_OTHER=false

while IFS= read -r file; do
  case "$file" in
    docs/git-history.json|docs/graph-data.json)
      HAS_GRAPH=true
      ;;
    *)
      HAS_OTHER=true
      ;;
  esac
done <<< "$STAGED"

if $HAS_GRAPH && $HAS_OTHER; then
  echo "BLOCKED: docs/git-history.json and docs/graph-data.json cannot be committed alongside other files."
  echo "Either commit them alone (just those two files), or unstage them first."
  echo ""
  echo "Staged files:"
  echo "$STAGED"
  exit 2
fi
