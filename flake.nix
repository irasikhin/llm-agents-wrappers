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
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # The four commands share one multi-call script (bin/llm-agent-wrapper),
      # which dispatches on its own basename. This list is just the command
      # names it is installed under; the script itself is the source of truth.
      agents = [ "claude" "codex" "opencode" "pi" ];
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          lib = pkgs.lib;

          # The portable wrapper — identical to what install.sh puts on PATH for
          # non-Nix users. Installed under each command name so basename-dispatch
          # selects the right agent. shellcheck-gated so the flake check fails on
          # a broken script.
          script = ./bin/llm-agent-wrapper;

          mkAgent =
            name:
            pkgs.runCommandLocal name {
              nativeBuildInputs = [ pkgs.shellcheck ];
              meta = {
                description = "Proxy-aware ${name} agent-CLI wrapper";
                mainProgram = name;
                platforms = lib.platforms.unix;
              };
            } ''
              shellcheck ${script}
              install -Dm755 ${script} "$out/bin/${name}"
            '';

          wrappers = lib.genAttrs agents mkAgent;
        in
        wrappers
        // {
          default = pkgs.symlinkJoin {
            name = "llm-wrappers";
            paths = lib.attrValues wrappers;
            meta = {
              description = "Proxy-aware Claude, Codex, OpenCode and Pi agent-CLI wrappers";
              mainProgram = "claude";
              platforms = pkgs.lib.platforms.unix;
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
