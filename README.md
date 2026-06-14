# llm-wrappers

[![ci](https://github.com/irasikhin/llm-agents-wrappers/actions/workflows/ci.yml/badge.svg)](https://github.com/irasikhin/llm-agents-wrappers/actions/workflows/ci.yml)

Proxy-aware wrappers for LLM coding agents. One small launcher gives you four
commands — `claude`, `codex`, `opencode`, `pi` — that each:

- optionally export a scoped HTTP proxy (opt-in — only when a proxy is
  configured), so the agent's API traffic can be routed through it without
  polluting your global shell environment;
- export colour environment so the agent TUI renders in colour;
- run the upstream agent CLI through a selectable **runner**.

The wrapper only *launches* an agent — it does not install one (same way it does
not start the proxy). Install each agent however you like; the wrapper runs it.

Works on Linux and macOS, **with or without Nix**.

## Runners

The runner is chosen by `LLM_WRAPPERS_RUNNER` (default `auto`):

| Runner | What it does |
| --- | --- |
| `auto` (default) | use `nix` if it is on `PATH`, otherwise `native` |
| `nix` | `nix run github:numtide/llm-agents.nix#<attr>` — zero-install, reproducible |
| `native` | exec a native agent binary already on `PATH` (the wrapper skips itself) |

So a machine with Nix gets the reproducible `nix run` path automatically, and a
machine without Nix falls back to whatever you installed natively — no config
needed in either case.

## Install — without Nix

Install the four commands into `~/.local/bin`:

```bash
curl -fsSL https://raw.githubusercontent.com/irasikhin/llm-agents-wrappers/main/install.sh | sh
```

Or from a clone (symlinks point at your checkout):

```bash
git clone https://github.com/irasikhin/llm-agents-wrappers
sh llm-agents-wrappers/install.sh            # --bin-dir DIR to choose another dir
```

Uninstall (removes only the symlinks it created):

```bash
sh install.sh --uninstall
```

Then install the agent(s) you want — the wrapper runs them from `PATH`:

| Agent | Install (pick one) |
| --- | --- |
| `claude` | `curl -fsSL https://claude.ai/install.sh \| bash` · `npm install -g @anthropic-ai/claude-code` |
| `codex` | `npm install -g @openai/codex` · `brew install --cask codex` |
| `opencode` | `curl -fsSL https://opencode.ai/install \| bash` · `npm install -g opencode-ai` · `brew install sst/tap/opencode` |
| `pi` | `curl -fsSL https://pi.dev/install.sh \| sh` · `npm install -g --ignore-scripts @earendil-works/pi-coding-agent` |

`pi` collides with the unrelated `pi` π-calculator that some distros ship; if the
wrapper picks the wrong binary, point it at the right one with `PI_NATIVE_BIN`.

## Install — with Nix

Run directly from the flake source:

```bash
nix run github:irasikhin/llm-agents-wrappers#claude
nix run github:irasikhin/llm-agents-wrappers#codex
nix run github:irasikhin/llm-agents-wrappers#opencode
nix run github:irasikhin/llm-agents-wrappers#pi
```

Install into your profile (the `default` bundle installs all four; or pick
individual commands):

```bash
nix profile install github:irasikhin/llm-agents-wrappers#default
nix profile install github:irasikhin/llm-agents-wrappers#claude
```

Use from another flake:

```nix
{
  inputs.llm-wrappers.url = "github:irasikhin/llm-agents-wrappers";
}
```

```nix
environment.systemPackages = [
  llm-wrappers.packages.${pkgs.system}.default
];
```

For local development, point a flake input at a clone:

```nix
inputs.llm-wrappers.url = "path:.";
```

With Nix present, the wrappers default to the `nix run` path and pull each agent
from [`github:numtide/llm-agents.nix`](https://github.com/numtide/llm-agents.nix) —
no separate agent install needed.

## Session persistence

Your call: run a wrapper inside `tmux`, `zellij` or `screen` yourself if you want
the agent to survive a disconnected terminal.

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `LLM_WRAPPERS_RUNNER` | `auto` | runner: `auto`, `nix` or `native` |
| `LLM_WRAPPERS_PROXY_HOST` | _(unset → no proxy)_ | HTTP proxy host; when set, the proxy is exported |
| `LLM_WRAPPERS_PROXY_PORT` | `8888` (when host set) | HTTP proxy port |
| `CLAUDE_AGENT_FLAKE` | `github:numtide/llm-agents.nix#claude-code` | flakeref run by `claude` (nix runner) |
| `CODEX_AGENT_FLAKE` | `github:numtide/llm-agents.nix#codex` | flakeref run by `codex` (nix runner) |
| `OPENCODE_AGENT_FLAKE` | `github:numtide/llm-agents.nix#opencode` | flakeref run by `opencode` (nix runner) |
| `PI_AGENT_FLAKE` | `github:numtide/llm-agents.nix#pi` | flakeref run by `pi` (nix runner) |
| `CLAUDE_NATIVE_BIN` | _(auto-detect on PATH)_ | binary run by `claude` (native runner) |
| `CODEX_NATIVE_BIN` | _(auto-detect on PATH)_ | binary run by `codex` (native runner) |
| `OPENCODE_NATIVE_BIN` | _(auto-detect on PATH)_ | binary run by `opencode` (native runner) |
| `PI_NATIVE_BIN` | _(auto-detect on PATH)_ | binary run by `pi` (native runner) |

## Proxy

By default the wrappers connect directly. To route an agent through an HTTP
proxy, set the host (and optionally the port — it defaults to `8888`):

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

> The wrapper only *manages* the proxy when `LLM_WRAPPERS_PROXY_*` is set. When
> it is unset it leaves the ambient environment alone — so if your shell already
> exports `https_proxy`, the agent inherits it. To guarantee a direct connection
> regardless of the ambient shell, unset the proxy vars (see the `null` case in
> the baked snippet below).

### Reproducible proxy (Nix)

Setting `LLM_WRAPPERS_PROXY_*` on the command line is fine for one-offs but not
reproducible. Two declarative options:

**1. One proxy for all four — set the namespaced vars in your Nix config.**
Only the wrappers read these names, so this is effectively scoped to them:

```nix
# home-manager
home.sessionVariables = {
  LLM_WRAPPERS_PROXY_HOST = "10.0.0.5";
  LLM_WRAPPERS_PROXY_PORT = "3128";
};
# NixOS: environment.variables = { ... };  (same keys)
```

**2. Baked into the binaries — per-agent, shared, or forced-direct.**
Wrap the bundle so each command carries its own proxy in the Nix store, with no
ambient env needed. Per agent: `{ host; port; }` routes through that proxy,
`null` forces a direct connection (even if your shell exports a proxy), and an
agent you omit is left untouched. Give every agent the same value for one shared
proxy.

```nix
# `llm-wrappers` = this flake's input; `pkgs` = your nixpkgs.
let
  base = llm-wrappers.packages.${pkgs.system}.default;
  proxies = {
    claude   = { host = "10.0.0.5"; port = 3128; };
    codex    = { host = "10.0.0.9"; port = 8080; };
    opencode = null;                                  # direct, ignore ambient
    pi       = { host = "127.0.0.1"; port = 8888; };
  };
  mkArgs = p:
    if p == null
    then "--unset http_proxy --unset https_proxy --unset HTTP_PROXY "
       + "--unset HTTPS_PROXY --unset all_proxy --unset ALL_PROXY"
    else "--set LLM_WRAPPERS_PROXY_HOST ${p.host} "
       + "--set LLM_WRAPPERS_PROXY_PORT ${toString p.port}";
in
pkgs.symlinkJoin {
  name = "llm-wrappers-proxied";
  paths = [ base ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = pkgs.lib.concatStrings (pkgs.lib.mapAttrsToList (name: p: ''
    rm "$out/bin/${name}"
    makeWrapper ${base}/bin/${name} "$out/bin/${name}" ${mkArgs p}
  '') proxies);
}
```

Put the result in `environment.systemPackages` / `home.packages`. The proxy is
fixed at build time, so the binaries are reproducible and self-contained.
