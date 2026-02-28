# Opinionated AI Phoenix Generator

An opinionated `mix phx.new` wrapper that creates Phoenix projects with a complete AI-assisted development methodology built in — decision tracking, self-healing infrastructure, continuous quality enforcement, and design constraints that keep AI-generated code disciplined.

## The methodology at a glance

This generator sets up three interlocking systems:

1. **Decision graph** — Every meaningful change is tracked in a graph database. Future sessions recover full context via `/recover`. The graph deploys as a browsable web viewer.
2. **Self-healing infrastructure** — Background monitors watch container logs and auto-diagnose/fix errors. Claude subagents read stacktraces, edit source files, verify with tests, and log everything to the decision graph.
3. **Quality gates** — Compilation warnings are errors. Credo runs in strict mode. Dialyzer enforces type contracts. An AI refactoring pass catches what linters miss. All of this runs before every commit.

The design constraints (type-first, functional core/imperative shell, explicit git staging, linear history) exist because AI-generated code needs more guardrails, not fewer.

## Prerequisites

- [Elixir](https://elixir-lang.org/install.html) 1.19+ with OTP 28+
- [Phoenix](https://hexdocs.pm/phoenix/installation.html) (`mix archive.install hex phx_new`)
- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- [deciduous](https://github.com/durable-creative/deciduous) (`cargo install deciduous`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [jq](https://jqlang.github.io/jq/) (for JSON patching during setup)
- git

## Generate a project

```bash
./phx_ai_new.sh my_app
```

Or with `mix phx.new` options:

```bash
./phx_ai_new.sh my_app --no-mailer --no-dashboard
```

The generator runs through these steps:

1. `mix phx.new my_app` with your options
2. `git init` + initial commit
3. `deciduous init --claude` — decision graph database, 9 Claude commands, 3 skills, 2 hooks, GitHub Pages workflow, CLAUDE.md base
4. Docker overlay — dev container with hot reload, production release Dockerfile, graph viewer container, docker-compose with Postgres
5. Makefile with 23 dev targets
6. 4 Claude commands — `/heal`, `/listen`, `/monitor`, `/improve-elixir`
7. GitHub Actions CI — compile, credo, test, dialyzer
8. Credo strict mode config + dialyxir injected into `mix.exs`
9. Pre-commit hook that blocks mixed graph-data commits
10. CLAUDE.md appendix with Phoenix/Elixir/LiveView design guidelines
11. `mix deps.get && mix format`
12. Single commit with the full overlay

After it finishes, you have a Phoenix project with two git commits: the vanilla `mix phx.new` output and the AI tooling overlay.

## Start developing

```bash
cd my_app
make up        # Build and start containers (app + postgres)
make watch     # File sync for hot reload (separate terminal, required on macOS)
make setup     # Create database and run migrations (first time only)
```

The app runs at `http://localhost:4000`. Decision graph viewer at `http://localhost:3000` (`make graph`).

### Why `make watch` is required

On macOS, Docker volume mounts don't propagate inotify events. `docker compose watch` syncs files into the container and triggers the filesystem events Phoenix live reload needs. Without it, code changes won't reflect in the browser. Always run `make watch` in a separate terminal alongside `make up`.

---

## The development loop

This is the workflow the generator establishes. Every step is enforced by tooling, not honor system.

### 1. Start a work transaction

Every meaningful unit of work begins with:

```
/work "Add user authentication with JWT"
```

This creates a **goal node** in the decision graph with your verbatim request captured. "Meaningful" means any change a future session would want to understand. Trivial one-line typo fixes can skip this.

The decision graph follows a strict flow:

```
goal → options → decision → actions → outcomes
```

- **Goals** define what you want to accomplish
- **Options** explore possible approaches (goals lead to options, not directly to decisions)
- **Decisions** choose which option to pursue
- **Actions** implement the chosen approach
- **Outcomes** record what happened

Observations attach anywhere relevant. Root goal nodes are the only valid orphans — everything else must link to its parent.

### 2. Write code with design constraints

The generator enforces three design principles in CLAUDE.md:

**Type-first design** — Every new module starts with types before implementation:

```elixir
defmodule MyApp.Game.Board do
  @type cell :: :empty | :dark | :light
  @type t :: %__MODULE__{
    grid: %{{non_neg_integer(), non_neg_integer()} => cell()},
    cols: pos_integer(),
    rows: pos_integer()
  }

  defstruct grid: %{}, cols: 10, rows: 20

  @spec place_piece(t(), Piece.t(), {integer(), integer()}) :: {:ok, t()} | :collision
  def place_piece(board, piece, position) do
    # Implementation follows from the types
  end
end
```

**Functional core, imperative shell** — All business logic lives in pure functions on structs. LiveViews and GenServers are thin shells that call into the core:

```elixir
# Pure core — testable, no side effects
Engine.tick(game_state)       # GameState → GameState
Board.find_matches(board)     # Board → Board

# Imperative shell — orchestrates side effects
def handle_info(:tick, socket) do
  game = Engine.tick(socket.assigns.game)
  {:noreply, assign(socket, game: game)}
end
```

**No OO constructors** — No `.new()` functions. Construct structs directly with `%Module{field: value}`. The `defstruct` defaults are the single source of truth.

### 3. Run the quality gate

Before every commit:

```bash
make quality
```

This runs six checks in sequence, continuing through failures so you see everything at once:

| Step | Command | What it catches |
|------|---------|----------------|
| 1 | `mix compile --warnings-as-errors` | Unused variables, missing imports, deprecations |
| 2 | `mix credo --strict` | 100+ style, design, readability, and refactoring rules |
| 3 | `mix test` | Broken behavior |
| 4 | `mix dialyzer` | Type contract violations |
| 5 | `/improve-elixir` on changed files | Patterns a linter can't catch — AI refactoring pass |
| 6 | `mix format` | Formatting |

If credo found issues, the `/improve-elixir` step receives the credo output and fixes those too.

The same pipeline runs in CI via GitHub Actions on every push and PR to main.

### 4. Commit with explicit staging

The generator enforces strict git hygiene:

```bash
# Stage files explicitly by name — NEVER use git add -A or git add .
git add lib/my_app/auth.ex lib/my_app_web/live/login_live.ex test/my_app/auth_test.exs

git commit -m "feat: add JWT authentication"
```

Then link the commit to the decision graph:

```bash
deciduous add action "Implemented JWT auth" -c 90 --commit HEAD -f "lib/my_app/auth.ex,lib/my_app_web/live/login_live.ex"
deciduous link <goal_id> <action_id> -r "Implementation"
```

The `--commit HEAD` flag captures the commit hash. The web viewer shows commit messages, authors, and dates alongside decision nodes.

**Graph data protection**: A pre-commit hook blocks commits that mix `docs/graph-data.json` with other files. Graph exports must be committed separately:

```bash
# This is BLOCKED:
git add lib/auth.ex docs/graph-data.json && git commit

# This is allowed:
git add docs/graph-data.json docs/git-history.json && git commit -m "update graph"
```

### 5. Recover context next session

When you start a new session:

```
/recover
```

This rebuilds full context from the decision graph — what was done, why, what worked, what failed. No more "what was I working on?" guessing.

---

## Self-healing infrastructure

The generator includes three Claude commands that auto-diagnose and fix runtime errors:

### `/heal` — one-shot diagnosis

Starts the containers, reads the logs, finds the error, reads the stacktrace, edits the source file, verifies with `mix compile --warnings-as-errors && mix test`, and logs everything to the decision graph. Maximum 3 fix attempts before asking for help.

```bash
make heal
```

### `/listen` — continuous error watcher

Long-running process that polls container logs every 10 seconds. Classifies errors by severity:

- **Critical** (app down): crashes, FATAL DB errors, container exits → fixes immediately
- **Error** (degraded): runtime errors, failed requests → fixes immediately
- **Warning**: one-off errors → waits for 3 occurrences in 60 seconds before acting

Never fixes the same error more than twice. Escalates to the user with a clear message when it can't auto-heal.

```bash
make listen
```

### `/monitor` — background supervisor

Launches three background subagents — containers, file watcher, and error listener — then returns control to you. You keep working while the monitor handles errors silently.

```bash
make monitor
```

All three commands log observations, actions, and outcomes to the decision graph. After a healing session, `/recover` shows what broke and how it was fixed.

---

## Decision graph lifecycle

### During development

Every `/work` transaction creates nodes and edges:

```bash
deciduous add goal "Add dark mode" -c 90 -p "User's verbatim request here"
deciduous add option "CSS custom properties" -c 80
deciduous add option "Tailwind dark: variant" -c 85
deciduous link <goal> <option1> -r "Possible approach"
deciduous link <goal> <option2> -r "Possible approach"
deciduous add decision "Use Tailwind dark variant" -c 90
deciduous link <option2> <decision> -r "Chosen for simplicity"
deciduous add action "Implement dark mode toggle" -c 85 --commit HEAD
deciduous link <decision> <action> -r "Implementation"
deciduous add outcome "Dark mode working" -c 95
deciduous link <action> <outcome> -r "Verified"
```

### Viewing the graph

```bash
make graph                    # Start web viewer at localhost:3000
deciduous nodes               # List all nodes
deciduous edges               # List all edges
deciduous nodes --branch main # Filter by branch
```

### Exporting and deploying

```bash
deciduous sync   # Export graph + git history to docs/
git add docs/graph-data.json docs/git-history.json
git commit -m "update decision graph"
git push
```

With GitHub Pages configured to deploy from `/docs`, the graph is live at `https://<user>.github.io/<repo>/`.

### Session start checklist

```bash
deciduous check-update    # Update needed?
deciduous nodes            # What decisions exist?
deciduous edges            # How are they connected?
deciduous doc list         # Any attached documents?
git status                 # Current state
```

---

## All Make targets

| Target | Description |
|--------|-------------|
| **Docker** | |
| `make up` | Build and start containers (app + postgres). `PORT=8080 make up` for custom port |
| `make down` | Stop everything |
| `make watch` | File sync for hot reload (blocking, run in separate terminal) |
| `make logs` | Tail container logs |
| `make graph` | Start decision graph viewer. `GRAPH_PORT=3001 make graph` for custom port |
| **Database** | |
| `make setup` | Create database and run migrations (first time) |
| `make migrate` | Run pending migrations |
| `make backup` | Dump database to `backups/` |
| **Shell** | |
| `make iex` | IEx shell on the running app container |
| `make shell` | Bash shell inside the app container |
| **Self-healing** | |
| `make heal` | One-shot error diagnosis and fix |
| `make listen` | Continuous error watcher |
| `make monitor` | Background supervisor (containers + watcher + listener) |
| **Code quality** | |
| `make compile` | `mix compile --warnings-as-errors` |
| `make test` | Compile + test suite |
| `make credo` | Credo strict mode |
| `make dialyzer` | Dialyzer static analysis |
| `make format` | `mix format` |
| `make improve` | AI refactoring pass via `/improve-elixir` |
| `make quality` | Full pipeline: compile, credo, test, dialyzer, improve, format |

---

## All Claude commands

| Command | Description |
|---------|-------------|
| **From deciduous (base)** | |
| `/decision` | Manage decision graph — add nodes, link edges, sync |
| `/recover` | Recover context from decision graph on session start |
| `/work` | Start a work transaction — creates goal node before implementation |
| `/document` | Generate comprehensive documentation for a file or directory |
| `/build-test` | Build the project and run the test suite |
| `/serve-ui` | Start the decision graph web viewer |
| `/sync-graph` | Export decision graph to GitHub Pages |
| `/decision-graph` | Build a decision graph from commit history |
| `/sync` | Multi-user sync — pull events, rebuild, push |
| **From this generator** | |
| `/heal` | One-shot error diagnosis and fix |
| `/listen` | Continuous error watcher with auto-heal |
| `/monitor` | Background supervisor — containers + watcher + listener |
| `/improve-elixir` | AI code quality pass — TDD, patterns, style, dead code removal |

Skills from deciduous: `/pulse` (map current design), `/narratives` (understand evolution), `/archaeology` (transform narratives into graph).

---

## CI pipeline

GitHub Actions runs on every push and PR to main:

| Step | What it does |
|------|-------------|
| Setup | Elixir 1.19 + OTP 28 + Postgres 16 (test DB) |
| Cache | deps, _build, PLT files (keyed by mix.lock hash) |
| Compile | `mix compile --warnings-as-errors` |
| Lint | `mix credo --strict` |
| Test | `mix test` |
| Analyze | `mix dialyzer` (PLT cached across runs) |

All checks must pass or the PR is blocked.

---

## Docker architecture

Three services in `docker-compose.yml`:

**app** (Dockerfile.dev) — Elixir 1.19 + OTP 28 dev container. Mounts lib, assets, priv, config, test for hot reload via `docker compose watch`. Runs `mix ecto.create && mix ecto.migrate && mix phx.server`. Port 4000.

**db** (postgres:17-alpine) — Persistent volume `pgdata`. Healthcheck with `pg_isready`. Port 5432.

**graph** (Dockerfile.graph) — Deciduous web viewer built from Rust. Mounts `.deciduous/` directory. Port 3000.

A production Dockerfile (multi-stage Elixir release) is also included for deployment. It builds assets, creates a release, and runs as the `nobody` user.

---

## What the generator produces

After running `./phx_ai_new.sh my_app`, the project contains:

| File | Source | Purpose |
|------|--------|---------|
| `Dockerfile` | Templated | Production multi-stage release |
| `Dockerfile.dev` | Copied | Dev container with hot reload |
| `Dockerfile.graph` | Copied | Decision graph viewer |
| `docker-compose.yml` | Templated | Three services: app, db, graph |
| `Makefile` | Templated | 23 dev targets |
| `.credo.exs` | Copied | Credo strict mode config |
| `.github/workflows/ci.yml` | Templated | CI pipeline |
| `.claude/commands/heal.md` | Copied | Self-healing command |
| `.claude/commands/listen.md` | Copied | Continuous error listener |
| `.claude/commands/monitor.md` | Copied | Background supervisor |
| `.claude/commands/improve-elixir.md` | Copied | AI refactoring pass |
| `.claude/hooks/protect-graph-data.sh` | Copied | Pre-commit graph data guard |
| `CLAUDE.md` (appended) | Concatenated | Design philosophy + Phoenix guidelines |
| `mix.exs` (modified) | Patched | Adds dialyxir dep + precommit alias |
| `.claude/settings.json` (modified) | Patched | Registers the pre-commit hook |
| `README.md` | Templated | Development methodology guide |

Template placeholders (`__APP_NAME__`, `__APP_NAME_MODULE__`) are substituted with the snake_case and CamelCase app name.

Files from `deciduous init --claude` (decision graph database, 9 commands, 3 skills, 2 hooks, GitHub Pages workflow, CLAUDE.md base) are created before the overlay and not listed here.

---

## Design principles

These are the opinions encoded in this generator:

1. **Institutional memory over documentation** — Decision graphs capture what changed, why, what alternatives were considered, and what happened. Documentation goes stale; a graph of linked decisions doesn't.

2. **Self-healing over manual debugging** — When an error appears in logs, an AI agent reads the stacktrace, identifies the file, applies a fix, and verifies with tests. Developers intervene only when auto-heal fails twice.

3. **Type-first design** — Define `@type`, `@spec`, `defstruct` before writing implementation. Types make module boundaries visible and composable. When the types are right, the implementation follows.

4. **Functional core, imperative shell** — All business logic is pure functions on structs. LiveViews and GenServers are thin wrappers that call into the core and manage side effects. This makes everything testable and extractable.

5. **Quality gates, not quality hopes** — `make quality` runs compile, credo, test, dialyzer, AI refactoring, and format. The same checks run in CI. Nothing merges without passing everything.

6. **Linear git history** — Rebase only, never merge. Explicit file staging only, never `git add -A`. Graph data exports are committed separately from code changes.

7. **AI needs more guardrails, not fewer** — The constraints exist because AI-generated code tends toward over-engineering, inconsistent patterns, and subtle bugs. Strict credo, dialyzer, type contracts, and design rules keep it disciplined.
