#!/bin/bash
set -euo pipefail

# Opinionated Phoenix + AI Development Generator
# Wraps mix phx.new and layers on Docker, deciduous, Claude Code, CI, and code quality tooling.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SCRIPT_DIR/templates"

usage() {
  echo "Usage: phx_ai_new.sh <app_name> [mix phx.new options...]"
  echo ""
  echo "Creates a new Phoenix project with AI development tooling:"
  echo "  - Docker dev environment with hot reload"
  echo "  - Deciduous decision graph for institutional memory"
  echo "  - Claude Code commands, hooks, and skills"
  echo "  - GitHub Actions CI (compile, credo, test, dialyzer)"
  echo "  - Code quality: Credo strict, dialyxir"
  echo "  - Self-healing infrastructure (heal, listen, monitor)"
  echo "  - Pre-commit hook protecting graph data files"
  echo ""
  echo "Prerequisites: mix, deciduous, git, docker, jq"
  exit 1
}

APP_NAME="${1:?$(usage)}"
shift
PHX_OPTS="${*:-}"

# Derive CamelCase module name from snake_case app name
# Use perl instead of sed — macOS sed doesn't support \U for uppercase
APP_MODULE=$(echo "$APP_NAME" | perl -pe 's/(^|_)(.)/uc($2)/ge')

echo "==> Creating Phoenix project: $APP_NAME (module: $APP_MODULE)"
echo ""

# 1. Run mix phx.new
mix phx.new "$APP_NAME" $PHX_OPTS

# 2. Enter project, init git
cd "$APP_NAME"
git init
git add -A
git commit -m "mix phx.new $APP_NAME"

echo ""
echo "==> Initializing deciduous decision graph..."

# 3. Run deciduous init (provides base Claude Code + deciduous setup)
deciduous init --claude

echo ""
echo "==> Layering AI development tooling..."

# 4. Copy generic files (no templating needed)
cp "$TEMPLATES/claude_commands/"*.md .claude/commands/
cp "$TEMPLATES/claude_hooks/protect-graph-data.sh" .claude/hooks/
chmod +x .claude/hooks/protect-graph-data.sh
cp "$TEMPLATES/docker/Dockerfile.dev" .
cp "$TEMPLATES/docker/Dockerfile.graph" .
cp "$TEMPLATES/ci.yml" .github/workflows/ci.yml
cp "$TEMPLATES/credo.exs" .credo.exs

# 5. Template files with app name substitution
sed -e "s/__APP_NAME__/$APP_NAME/g" -e "s/__APP_NAME_MODULE__/$APP_MODULE/g" \
  "$TEMPLATES/docker/Dockerfile.tmpl" > Dockerfile
sed -e "s/__APP_NAME__/$APP_NAME/g" -e "s/__APP_NAME_MODULE__/$APP_MODULE/g" \
  "$TEMPLATES/docker/docker-compose.yml.tmpl" > docker-compose.yml
sed -e "s/__APP_NAME__/$APP_NAME/g" -e "s/__APP_NAME_MODULE__/$APP_MODULE/g" \
  "$TEMPLATES/Makefile.tmpl" > Makefile

# 6. Template CI workflow with app name (for DB name)
sed -i '' -e "s/__APP_NAME__/$APP_NAME/g" .github/workflows/ci.yml 2>/dev/null || \
  sed -i -e "s/__APP_NAME__/$APP_NAME/g" .github/workflows/ci.yml

# 7. Append Phoenix-specific content to CLAUDE.md
cat "$TEMPLATES/claude_md_append.md" >> CLAUDE.md

# 8. Patch .claude/settings.json to add protect-graph-data hook
# Add the Bash matcher for protect-graph-data.sh to PreToolUse
jq '.hooks.PreToolUse += [{"matcher": "Bash", "hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR/.claude/hooks/protect-graph-data.sh\""}]}]' \
  .claude/settings.json > .claude/settings.json.tmp && mv .claude/settings.json.tmp .claude/settings.json

# 9. Add dialyxir to mix.exs deps
# Find the deps function and add dialyxir after the first dep line
if ! grep -q "dialyxir" mix.exs; then
  # Insert dialyxir as the first dep (after the opening of the deps list)
  sed -i '' -e '/defp deps do/,/\]/{
    /^\s*{:/!b
    :a
    N
    /\]$/!ba
    s/\]/      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}\n    \]/
  }' mix.exs 2>/dev/null || \
  sed -i -e '/defp deps do/,/\]/{
    /^\s*{:/!b
    :a
    N
    /\]$/!ba
    s/\]/      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}\n    \]/
  }' mix.exs
fi

# 10. Add precommit alias to mix.exs
if ! grep -q "precommit" mix.exs; then
  # Add aliases function or append to existing aliases
  if grep -q "defp aliases do" mix.exs; then
    sed -i '' -e '/defp aliases do/,/\]/{
      s/\]/      precommit: ["compile --warnings-as-errors", "credo --strict", "test", "dialyzer", "format"]\n    \]/
    }' mix.exs 2>/dev/null || \
    sed -i -e '/defp aliases do/,/\]/{
      s/\]/      precommit: ["compile --warnings-as-errors", "credo --strict", "test", "dialyzer", "format"]\n    \]/
    }' mix.exs
  fi
fi

# 11. Initial setup
echo ""
echo "==> Installing dependencies..."
mix deps.get
mix format

# 12. Commit the overlay
git add CLAUDE.md .claude/ .github/ .credo.exs Dockerfile Dockerfile.dev Dockerfile.graph \
  docker-compose.yml Makefile mix.exs mix.lock
git commit -m "$(cat <<EOF
add AI development tooling overlay

- Docker dev environment with hot reload (Dockerfile.dev, docker-compose.yml)
- Deciduous decision graph (commands, hooks, skills)
- Claude Code self-healing (heal, listen, monitor commands)
- GitHub Actions CI (compile, credo, test, dialyzer)
- Code quality: Credo strict mode, dialyxir
- Pre-commit hook protecting graph data files
- Makefile with 23 dev targets

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

echo ""
echo "==> Done! Your AI-powered Phoenix project is ready."
echo ""
echo "Next steps:"
echo "  cd $APP_NAME"
echo "  make up        # Build and start containers"
echo "  make watch     # Start file sync for hot reload"
echo "  make setup     # Create database and run migrations"
echo ""
echo "The app runs at http://localhost:4000"
echo "Decision graph at http://localhost:3000 (make graph)"
echo ""
echo "Key commands:"
echo "  /work \"description\"  # Start a tracked work transaction"
echo "  /recover              # Recover context from decision graph"
echo "  /monitor              # Launch background server + error listener"
echo "  make quality          # Full quality pipeline before committing"
