# Opinionated AI Phoenix Generator

An opinionated `mix phx.new` wrapper that layers a complete AI development workflow on top of a new Phoenix project.

## What it sets up

**From `deciduous init --claude` (base layer):**
- Decision graph database and config
- 9 Claude Code commands (`/decision`, `/recover`, `/work`, `/document`, `/build-test`, `/serve-ui`, `/sync-graph`, `/decision-graph`, `/sync`)
- 3 Claude Code skills (`/pulse`, `/narratives`, `/archaeology`)
- 2 Claude Code hooks (require-action-node, post-commit-reminder)
- GitHub Pages deployment workflow
- Decision graph cleanup workflow
- CLAUDE.md with deciduous workflow documentation

**Custom overlay (this generator):**
- Docker dev environment with hot reload via `docker compose watch`
- Production Dockerfile (multi-stage Elixir release)
- Deciduous graph viewer container (Rust build)
- Makefile with 23 dev targets
- 4 additional Claude commands (`/heal`, `/listen`, `/monitor`, `/improve-elixir`)
- GitHub Actions CI (compile, credo, test, dialyzer)
- Credo strict mode config
- Dialyxir for static analysis
- Pre-commit hook protecting `docs/graph-data.json` from mixed commits
- CLAUDE.md appendix: functional core/imperative shell, type-first design, Phoenix/Elixir/LiveView guidelines

## Prerequisites

- [Elixir](https://elixir-lang.org/install.html) 1.19+ with OTP 28+
- [Phoenix](https://hexdocs.pm/phoenix/installation.html) (`mix archive.install hex phx_new`)
- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- [deciduous](https://github.com/durable-creative/deciduous) (`cargo install deciduous`)
- [jq](https://jqlang.github.io/jq/) (for JSON patching during setup)
- git

## Usage

```bash
./phx_ai_new.sh my_app
```

Or with `mix phx.new` options:

```bash
./phx_ai_new.sh my_app --no-mailer --no-dashboard
```

This will:
1. Run `mix phx.new my_app` with your options
2. Initialize git and make an initial commit
3. Run `deciduous init --claude` for the decision graph base
4. Overlay Docker, Makefile, CI, code quality, and Claude commands
5. Inject `dialyxir` into `mix.exs`
6. Append Phoenix/Elixir guidelines to `CLAUDE.md`
7. Patch `.claude/settings.json` with the graph data protection hook
8. Run `mix deps.get` and `mix format`
9. Commit the full overlay

## After generation

```bash
cd my_app
make up        # Build and start containers (app + postgres)
make watch     # Start file sync for hot reload (separate terminal)
make setup     # Create database and run migrations (first time only)
```

The app runs at `http://localhost:4000`. Decision graph viewer at `http://localhost:3000` (`make graph`).

## Key workflows

| Command | What it does |
|---------|-------------|
| `make quality` | Full pipeline: compile, credo, test, dialyzer, improve-elixir, format |
| `make up` / `make down` | Start/stop Docker containers |
| `make watch` | File sync for hot reload (required on macOS) |
| `make logs` | Tail container logs |
| `make graph` | Start decision graph viewer |
| `/work "description"` | Start a tracked work transaction |
| `/recover` | Recover context from decision graph |
| `/monitor` | Launch background server + error listener |
| `/heal` | One-shot error diagnosis and fix |

## Template placeholders

Only 3 files use templating. The generator substitutes:
- `__APP_NAME__` → snake_case app name (e.g., `my_app`)
- `__APP_NAME_MODULE__` → CamelCase module name (e.g., `MyApp`)

Files: `Dockerfile.tmpl`, `docker-compose.yml.tmpl`, `Makefile.tmpl`, `ci.yml`

Everything else is fully generic and works for any Phoenix project.

## Design principles

This generator encodes opinions about AI-assisted development:

1. **Institutional memory**: Every meaningful change is tracked in a decision graph via `/work` transactions
2. **Self-healing**: Background monitors watch for errors and auto-fix them
3. **Type-first design**: Define `@type`, `@spec`, `defstruct` before implementation
4. **Functional core, imperative shell**: Pure functions for logic, thin LiveView/GenServer shell for side effects
5. **Linear history**: Rebase only, never merge. Explicit file staging, never `git add -A`
6. **Quality gates**: `make quality` runs the full pipeline before every commit
