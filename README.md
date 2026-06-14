# llm-wrappers

Proxy-aware wrappers for LLM coding agents. Each wrapper runs the upstream CLI
from [`github:numtide/llm-agents.nix`](https://github.com/numtide/llm-agents.nix):

- `claude` — runs `github:numtide/llm-agents.nix#claude-code`
- `codex` — runs `github:numtide/llm-agents.nix#codex`
- `opencode` — runs `github:numtide/llm-agents.nix#opencode`
- `pi` — runs `github:numtide/llm-agents.nix#pi`

Each wrapper:

- optionally exports an HTTP proxy (opt-in — only when a proxy is configured), so
  the agent's API traffic can be routed through it without polluting your global
  shell environment
- exports colour environment so the agent TUI renders in colour
- runs the target CLI via `nix run` from `github:numtide/llm-agents.nix`

Session persistence is your call: run a wrapper inside `tmux`, `zellij` or
`screen` yourself if you want the agent to survive a disconnected terminal.

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `LLM_WRAPPERS_PROXY_HOST` | _(unset → no proxy)_ | HTTP proxy host; when set, the proxy is exported |
| `LLM_WRAPPERS_PROXY_PORT` | `8888` (when host set) | HTTP proxy port |
| `CLAUDE_AGENT_FLAKE` | `github:numtide/llm-agents.nix#claude-code` | flakeref run by `claude` |
| `CODEX_AGENT_FLAKE` | `github:numtide/llm-agents.nix#codex` | flakeref run by `codex` |
| `OPENCODE_AGENT_FLAKE` | `github:numtide/llm-agents.nix#opencode` | flakeref run by `opencode` |
| `PI_AGENT_FLAKE` | `github:numtide/llm-agents.nix#pi` | flakeref run by `pi` |

## Proxy

By default the wrappers connect directly. To route an agent through an HTTP proxy,
set the host (and optionally the port — it defaults to `8888`):

```bash
export LLM_WRAPPERS_PROXY_HOST=127.0.0.1
export LLM_WRAPPERS_PROXY_PORT=8888
```

```bash
LLM_WRAPPERS_PROXY_HOST=10.0.0.5 \
LLM_WRAPPERS_PROXY_PORT=3128 \
nix run github:irasikhin/llm-agents-wrappers#codex
```

The proxy is exported only for the agent process the wrapper launches; your other
tools are unaffected. The wrapper does not start or manage the proxy service —
point it at a proxy that is already running.

## Nix flake usage

Run directly from the flake source:

```bash
nix run github:irasikhin/llm-agents-wrappers#claude
nix run github:irasikhin/llm-agents-wrappers#codex
nix run github:irasikhin/llm-agents-wrappers#opencode
nix run github:irasikhin/llm-agents-wrappers#pi
```

Install into your profile:

```bash
nix profile install github:irasikhin/llm-agents-wrappers#claude
nix profile install github:irasikhin/llm-agents-wrappers#codex
nix profile install github:irasikhin/llm-agents-wrappers#opencode
nix profile install github:irasikhin/llm-agents-wrappers#pi
```

Use from another flake:

```nix
{
  inputs.llm-wrappers.url = "github:irasikhin/llm-agents-wrappers";
}
```

For local development, point a flake input at a local clone:

```nix
inputs.llm-wrappers.url = "path:.";
```

Example package usage (the `default` bundle installs all four binaries):

```nix
environment.systemPackages = [
  llm-wrappers.packages.${pkgs.system}.default
];
```

Or install them individually:

```nix
environment.systemPackages = [
  llm-wrappers.packages.${pkgs.system}.claude
  llm-wrappers.packages.${pkgs.system}.codex
  llm-wrappers.packages.${pkgs.system}.opencode
  llm-wrappers.packages.${pkgs.system}.pi
];
```
