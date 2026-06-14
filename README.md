# llm-wrappers

[![ci](https://github.com/irasikhin/llm-agents-wrappers/actions/workflows/ci.yml/badge.svg)](https://github.com/irasikhin/llm-agents-wrappers/actions/workflows/ci.yml)

Proxy-aware wrappers for LLM coding agents. One small launcher gives you four
commands — `claude-proxy`, `codex-proxy`, `opencode-proxy`, `pi-proxy` — named
with a `-proxy` suffix so they never shadow the base `claude`/`codex`/… binaries
they launch. Each command:

- **requires a live proxy by default** and refuses to launch without one, so the
  agent can never reach the API directly (fail-closed; opt out if you want);
- **watches the proxy's external (egress) IP** — a new/changed egress IP (a
  different proxy) raises an alert and must be confirmed interactively before the
  launch proceeds, and is then remembered;
- exports colour environment so the agent TUI renders in colour;
- runs the upstream agent CLI through a selectable **runner**.

The wrapper only *launches* an agent — it does not install one. Install each
agent however you like; the wrapper runs it. Works on Linux and macOS, **with or
without Nix**.

## Runners

The runner is chosen by `LLM_WRAPPERS_RUNNER` (default `auto`):

| Runner | What it does |
| --- | --- |
| `auto` (default) | use `nix` if it is on `PATH`, otherwise `native` |
| `nix` | `nix run github:numtide/llm-agents.nix#<attr>` — zero-install, reproducible |
| `native` | exec a native agent binary already on `PATH` |

## Mandatory proxy & egress monitoring

By default every command **fails closed**: it refuses to launch unless a proxy is
both configured and accepting connections (a quick TCP probe). This guarantees
the agent's traffic leaves through the proxy, never directly.

While a proxy is active, the wrapper also checks the **external IP** the proxy
exits from (via `api.ipify.org` / `ifconfig.me` / `icanhazip.com`, fetched
through the proxy). Approved IPs are remembered in
`${XDG_STATE_HOME:-~/.local/state}/llm-wrappers/known-egress`, with a log in
`egress-history`. When the egress IP is new — i.e. traffic would leave through a
different proxy than before — you get an alert and a prompt:

```
⚠  claude: NEW egress IP via proxy http://10.0.0.5:3128
   egress IP : 203.0.113.7
   approved  : 198.51.100.2
Approve this egress IP and continue? [y/N]
```

Answer `y` to record it and launch; anything else aborts. The prompt is read from
the terminal (`/dev/tty`), so a **non-interactive** run with an unknown egress IP
fails closed (never auto-approves).

Knobs (all overridable per agent and settable in the [config file](#config-file)):

- opt out of the requirement: `LLM_WRAPPERS_REQUIRE_PROXY=0` (or `<AGENT>_REQUIRE_PROXY=0`);
- disable the egress check: `LLM_WRAPPERS_EGRESS_CHECK=off`;
- timeouts: `LLM_WRAPPERS_PROXY_TIMEOUT` (TCP probe, default `3`s),
  `LLM_WRAPPERS_EGRESS_TIMEOUT` (IP probe, default `8`s).

## Install — without Nix

Install the four `-proxy` commands into `~/.local/bin`:

```bash
curl -fsSL https://raw.githubusercontent.com/irasikhin/llm-agents-wrappers/main/install.sh | sh
```

The mandatory-proxy default is on. You can bake policy into the install (writes
the config file):

```bash
sh install.sh --require-proxy --proxy-host 10.0.0.5 --proxy-port 3128
sh install.sh --no-require-proxy        # opt out of the requirement
sh install.sh --no-suffix               # bare names claude/codex/… (shadows base tools)
```

Uninstall (removes only the symlinks it created; `--purge` also removes config):

```bash
sh install.sh --uninstall          # add --purge to drop the config file too
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

Run directly from the flake source (the attrs are the bare agent names; each
produces a `<agent>-proxy` binary):

```bash
nix run github:irasikhin/llm-agents-wrappers#claude      # runs claude-proxy
nix run github:irasikhin/llm-agents-wrappers#codex
```

Install into your profile (the `default` bundle installs all four):

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

## Config file

Defaults can be set in a config file of `KEY=value` lines (only `LLM_WRAPPERS_*`
and `<AGENT>_*` keys are honoured). It is read from `$LLM_WRAPPERS_CONFIG` (if
set) then `${XDG_CONFIG_HOME:-~/.config}/llm-wrappers/config`. `install.sh` writes
it for you with `--require-proxy` / `--no-require-proxy` / `--proxy-host` /
`--proxy-port`.

```ini
LLM_WRAPPERS_REQUIRE_PROXY=1
LLM_WRAPPERS_PROXY_HOST=10.0.0.5
LLM_WRAPPERS_PROXY_PORT=3128
```

Precedence: the runtime environment wins over the config file, which wins over
the built-in defaults.

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `LLM_WRAPPERS_RUNNER` | `auto` | runner: `auto`, `nix` or `native` |
| `LLM_WRAPPERS_REQUIRE_PROXY` | `1` | require a live proxy; `0`/`off` to opt out |
| `LLM_WRAPPERS_EGRESS_CHECK` | `on` | monitor the egress IP; `off` to disable |
| `LLM_WRAPPERS_EGRESS_IP` | _(auto-probe)_ | override the detected egress IP |
| `LLM_WRAPPERS_PROXY_TIMEOUT` | `3` | seconds for the proxy TCP reachability probe |
| `LLM_WRAPPERS_EGRESS_TIMEOUT` | `8` | seconds for the egress-IP probe |
| `LLM_WRAPPERS_PROXY_HOST` | _(unset → no proxy)_ | HTTP proxy host |
| `LLM_WRAPPERS_PROXY_PORT` | `8888` (when host set) | HTTP proxy port |
| `LLM_WRAPPERS_PROXY` | _(unset)_ | `off`/`none`/`direct` forces a direct connection |
| `LLM_WRAPPERS_CONFIG` | _(unset)_ | path to an extra config file |
| `<AGENT>_AGENT_FLAKE` | upstream flakeref | flakeref run by that agent (nix runner) |
| `<AGENT>_NATIVE_BIN` | _(auto-detect on PATH)_ | binary run by that agent (native runner) |

`<AGENT>` ∈ `CLAUDE`/`CODEX`/`OPENCODE`/`PI`. Every `LLM_WRAPPERS_*` proxy setting
has a per-agent override that wins over the global one:

| Variable | Purpose |
| --- | --- |
| `<AGENT>_PROXY_HOST` / `<AGENT>_PROXY_PORT` | per-agent proxy, falling back to the global host/port then defaults |
| `<AGENT>_PROXY` | per-agent `off`/`none`/`direct` toggle |
| `<AGENT>_REQUIRE_PROXY` | per-agent require toggle (`0` to opt out) |

Most-specific wins: `<AGENT>_PROXY=off` › `<AGENT>_PROXY_HOST/PORT` › `LLM_WRAPPERS_PROXY=off` › `LLM_WRAPPERS_PROXY_HOST/PORT` › leave the ambient environment untouched.

## Proxy

To route an agent through an HTTP proxy, set the host (and optionally the port —
it defaults to `8888`):

```bash
export LLM_WRAPPERS_PROXY_HOST=10.0.0.5 LLM_WRAPPERS_PROXY_PORT=3128
```

The proxy is exported only for the agent process the wrapper launches; your other
tools are unaffected. The wrapper does not start or manage the proxy service —
point it at a proxy that is already running.

Per-agent overrides let you send each agent somewhere different — or force one
direct while the rest share a proxy:

```bash
export LLM_WRAPPERS_PROXY_HOST=10.0.0.5 LLM_WRAPPERS_PROXY_PORT=3128
export CODEX_PROXY=off          # codex goes direct (needs CODEX_REQUIRE_PROXY=0 too)
export CLAUDE_PROXY_HOST=1.2.3.4 # claude through its own proxy, port falls back to 3128
```

`<AGENT>_PROXY=off` (or `LLM_WRAPPERS_PROXY=off`) also *clears* any proxy your
shell already exported, so a forced-direct agent is hermetic.

### Reproducible proxy (Nix)

Setting these on the command line is fine for one-offs but not reproducible. Two
declarative options:

**1. Session vars in your Nix config — global or per-agent.**
Only the wrappers read these names, so this is effectively scoped to them:

```nix
# home-manager (NixOS: environment.variables = { ... }; — same keys)
home.sessionVariables = {
  LLM_WRAPPERS_PROXY_HOST = "10.0.0.5";   # shared default for all four
  LLM_WRAPPERS_PROXY_PORT = "3128";
  CLAUDE_PROXY_HOST = "1.2.3.4";          # claude overrides the host
  CODEX_PROXY = "off";                     # codex forced direct
  CODEX_REQUIRE_PROXY = "0";
};
```

**2. Baked into the binaries — per-agent, shared, or forced-direct.**
Wrap the bundle so each command carries its own policy in the Nix store. Per
agent: `{ host; port; }` routes through that proxy, `null` forces a direct
connection (and drops the requirement), and an agent you omit is left untouched.

```nix
# `llm-wrappers` = this flake's input; `pkgs` = your nixpkgs.
let
  base = llm-wrappers.packages.${pkgs.system}.default;
  proxies = {
    claude   = { host = "10.0.0.5"; port = 3128; };
    codex    = { host = "10.0.0.9"; port = 8080; };
    opencode = null;                                  # direct
    pi       = { host = "127.0.0.1"; port = 8888; };
  };
  mkArgs = p:
    if p == null
    then "--set LLM_WRAPPERS_PROXY off --set LLM_WRAPPERS_REQUIRE_PROXY 0"
    else "--set LLM_WRAPPERS_PROXY_HOST ${p.host} "
       + "--set LLM_WRAPPERS_PROXY_PORT ${toString p.port}";
in
pkgs.symlinkJoin {
  name = "llm-wrappers-proxied";
  paths = [ base ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = pkgs.lib.concatStrings (pkgs.lib.mapAttrsToList (name: p: ''
    rm "$out/bin/${name}-proxy"
    makeWrapper ${base}/bin/${name}-proxy "$out/bin/${name}-proxy" ${mkArgs p}
  '') proxies);
}
```

Put the result in `environment.systemPackages` / `home.packages`. The policy is
fixed at build time, so the binaries are reproducible and self-contained.

## Session persistence

Your call: run a wrapper inside `tmux`, `zellij` or `screen` yourself if you want
the agent to survive a disconnected terminal.
