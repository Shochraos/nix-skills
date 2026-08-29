{
  description = "Agent skills, packaged";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };

    nixos-skill = {
      url = "github:marceloeatworld/nixos-ai-skill";
      flake = false;
    };

    vercel-skills = {
      url = "github:vercel-labs/skills";
      flake = false;
    };

    wshobson-agents = {
      url = "github:wshobson/agents";
      flake = false;
    };
    qt-agent-skills = {
      url = "github:TheQtCompanyRnD/agent-skills";
      flake = false;
    };
    anthropics-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      superpowers,
      nixos-skill,
      vercel-skills,
      wshobson-agents,
      qt-agent-skills,
      anthropics-skills,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor.${system};
          payloads = {
            superpowers-skills = pkgs.callPackage ./pkgs/superpowers-skills/package.nix {
              src = superpowers;
            };
            vendored-skills = pkgs.callPackage ./pkgs/vendored-skills/package.nix {
              inherit (inputs)
                nixos-skill
                vercel-skills
                wshobson-agents
                qt-agent-skills
                anthropics-skills
                ;
            };
            managed-skills = pkgs.callPackage ./pkgs/managed-skills/package.nix {
              src = ./skills;
            };
          };
        in
        payloads
        // {
          default = pkgs.symlinkJoin {
            name = "nix-skills";
            paths = nixpkgs.lib.attrValues payloads;
          };
        }
      );

      checks = forAllSystems (system: self.packages.${system});

      formatter = forAllSystems (system: pkgsFor.${system}.nixfmt-tree);

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixfmt
              pkgs.nixd
            ];
          };
        }
      );
    };
}
