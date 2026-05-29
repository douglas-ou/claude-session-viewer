# Claude Code Session Viewer

A local web viewer for browsing and inspecting your [Claude Code](https://docs.anthropic.com/en/docs/claude-code) conversation sessions.

## Features

- **Session browser** — Lists all sessions from `~/.claude/projects/` with project name, title, size, and last modified time
- **Timeline view** — Visual message timeline showing user/assistant/system turns with role-based color coding
- **Subagent support** — Displays subagent sessions linked to their parent conversations
- **Search & filter** — Search sessions by project name, UUID, or title; filter by role type
- **Zero dependencies** — Pure Python + HTML/CSS/JS, no npm or pip install needed

## Quick Start

```bash
# Clone the repo
git clone https://github.com/douglas-ou/tools.git
cd tools

# Start the server
./run.sh
```

Or run directly with Python:

```bash
python3 serve.py
```

The viewer opens automatically at `http://localhost:8124`.

## How It Works

```
run.sh / serve.py   →   HTTP server on localhost:8124
       ↓
Reads JSONL files from ~/.claude/projects/
       ↓
session-viewer.html →   Frontend renders session list & timeline
```

`serve.py` is a lightweight HTTP server that:
1. Scans `~/.claude/projects/` for `.jsonl` session files
2. Decodes Claude's encoded directory names back to readable project paths
3. Serves a REST API (`/api/files`, `/file`) for the frontend to query

`session-viewer.html` is a single-file frontend that renders the session list, message timeline, and search/filter UI.

## Requirements

- Python 3.7+
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with existing session data

## License

MIT
