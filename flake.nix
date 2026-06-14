{
  description = "Proxy-aware Claude, Codex, OpenCode and Pi agent-CLI wrappers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # The wrappers are identical bar the binary name and the upstream
      # llm-agents.nix attribute they run — so they are generated from this
      # one list rather than maintained as separate scripts.
      agents = [
        { name = "claude"; attr = "claude-code"; }
        { name = "codex"; attr = "codex"; }
        { name = "opencode"; attr = "opencode"; }
        { name = "pi"; attr = "pi"; }
      ];
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          lib = pkgs.lib;

          # One wrapper: optionally export a scoped HTTP proxy (opt-in — only when
          # LLM_WRAPPERS_PROXY_HOST/PORT is set, so a bare machine connects
          # directly), force colour into the agent TUI, then `nix run` the upstream
          # CLI. The flake ref is overridable per tool via <TOOL>_AGENT_FLAKE.
          mkAgent =
            { name, attr }:
            let
              envPrefix = lib.toUpper name;
            in
            pkgs.writeShellApplication {
              inherit name;
              text = ''
                flake="''${${envPrefix}_AGENT_FLAKE:-github:numtide/llm-agents.nix#${attr}}"

                # Opt-in scoped proxy: set LLM_WRAPPERS_PROXY_HOST and/or
                # LLM_WRAPPERS_PROXY_PORT to route this agent through an HTTP proxy.
                # Unset (the default) means a direct connection.
                if [ -n "''${LLM_WRAPPERS_PROXY_HOST:-}''${LLM_WRAPPERS_PROXY_PORT:-}" ]; then
                  proxy_url="http://''${LLM_WRAPPERS_PROXY_HOST:-127.0.0.1}:''${LLM_WRAPPERS_PROXY_PORT:-8888}"
                  export http_proxy="$proxy_url" https_proxy="$proxy_url" \
                         HTTP_PROXY="$proxy_url" HTTPS_PROXY="$proxy_url" \
                         all_proxy="$proxy_url" ALL_PROXY="$proxy_url"
                fi

                unset NO_COLOR
                export CLICOLOR=1 CLICOLOR_FORCE=1 FORCE_COLOR=1
                export TERM="''${TERM:-xterm-256color}" COLORTERM="''${COLORTERM:-truecolor}"

                if ! command -v nix >/dev/null 2>&1; then
                  echo "nix not found on PATH" >&2
                  exit 1
                fi

                exec nix run --no-write-lock-file "$flake" -- "$@"
              '';
            };

          wrappers = lib.listToAttrs (
            map (a: lib.nameValuePair a.name (mkAgent a)) agents
          );
        in
        wrappers
        // {
          default = pkgs.symlinkJoin {
            name = "llm-wrappers";
            paths = lib.attrValues wrappers;
            meta = {
              description = "Proxy-aware Claude, Codex, OpenCode and Pi agent-CLI wrappers";
              mainProgram = "claude";
              platforms = pkgs.lib.platforms.linux;
            };
          };
        }
      );

      overlays.default = final: prev: {
        llm-wrappers = self.packages.${prev.system}.default;
        claude = self.packages.${prev.system}.claude;
        codex = self.packages.${prev.system}.codex;
        # opencode/pi deliberately NOT exposed as bare overlay attrs: both names
        # exist in nixpkgs (pi = the π calculator) and would be shadowed globally.
        # Consume them via packages.<system>.{opencode,pi} or the default bundle.
        llm-wrappers-opencode = self.packages.${prev.system}.opencode;
        llm-wrappers-pi = self.packages.${prev.system}.pi;
      };
    };
}
