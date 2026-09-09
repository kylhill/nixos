{
  description = "Kyle Hill's NixOS infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim/nixos-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    solarized-nvim = {
      url = "github:maxmx03/solarized.nvim";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      disko,
      ...
    }:
    let
      inventory = import ./lib/inventory.nix;
      homeInventory = import ./lib/home-inventory.nix;
      devSystems = nixpkgs.lib.unique (
        map (host: host.system) (builtins.attrValues inventory.hosts ++ builtins.attrValues homeInventory)
      );
      forAllSystems = nixpkgs.lib.genAttrs devSystems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
      unfreePackages = [
        "github-copilot-cli"
        "vscode"
      ];
      mkPkgs =
        nixpkgsInput: system:
        import nixpkgsInput {
          inherit system;
          config.allowUnfreePredicate = package: builtins.elem (nixpkgs.lib.getName package) unfreePackages;
        };
      mkHost =
        hostName: host:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./modules/nixos/infrastructure.nix
            (./hosts + "/${hostName}")
            {
              infrastructure = {
                host = builtins.removeAttrs host [ "system" ];
                inherit (inventory) user network;
              };
              networking.hostName = hostName;
              nixpkgs.hostPlatform = host.system;
              nix.registry.nixpkgs.flake = inputs.nixpkgs;
              nix.nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];
            }
          ];
        };
      mkHome =
        homeName: home:
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs inputs.nixpkgs home.system;
          extraSpecialArgs = {
            inherit inputs;
            latestPkgs = mkPkgs inputs.nixpkgs-unstable home.system;
            homeIdentity = inventory.user // {
              inherit (home) homeDirectory;
            };
            networkHosts = inventory.network.hosts;
          };
          modules = [
            (./homes + "/${homeName}.nix")
            {
              home.stateVersion = home.stateVersion;
            }
          ];
        };
    in
    {
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost inventory.hosts;
      homeConfigurations = nixpkgs.lib.mapAttrs mkHome homeInventory;

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          fixtureCheck =
            suite:
            pkgs.runCommand "${suite}-fixtures"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.git
                  pkgs.gnugrep
                ];
              }
              ''
                bash ${self}/tests/${suite}.sh
                touch $out
              '';
        in
        {
          apply-fixtures = fixtureCheck "test-apply";
          runner-fixtures = fixtureCheck "test-runner";

          formatting =
            pkgs.runCommand "nixfmt-check"
              {
                nativeBuildInputs = [
                  pkgs.findutils
                  pkgs.nixfmt
                ];
              }
              ''
                find ${self} -type f -name '*.nix' -exec nixfmt --check {} +
                touch $out
              '';

          statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
            statix check ${self}
            touch $out
          '';

          deadnix = pkgs.runCommand "deadnix-check" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
            deadnix --fail ${self}
            touch $out
          '';

          shellcheck = pkgs.runCommand "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
            shellcheck \
              ${self}/apply.sh \
              ${self}/test.sh \
              ${self}/update.sh \
              ${self}/tests/test-apply.sh \
              ${self}/tests/test-runner.sh \
              ${self}/tests/fixtures/apply-tool \
              ${self}/tests/fixtures/validation-tool
            touch $out
          '';
        }
      );
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);

      apps = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          disko = {
            type = "app";
            program = "${disko.packages.${system}.disko}/bin/disko";
            meta.description = "Declaratively partition and format disks with Disko";
          };

          mcp-nixos = {
            type = "app";
            program = "${pkgs.mcp-nixos}/bin/mcp-nixos";
            meta.description = "Query version-matched NixOS and Home Manager documentation";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              pkgs.age
              pkgs.deadnix
              pkgs.fd
              pkgs.git
              (pkgs.lib.getBin pkgs.jq)
              pkgs.mcp-nixos
              pkgs.nixfmt
              pkgs.nixfmt-tree
              pkgs.ripgrep
              pkgs.shellcheck
              pkgs.statix
              (pkgs.lib.getBin pkgs.nix-eval-jobs)
              pkgs.nix-tree
              pkgs.nvd
              (pkgs.lib.getBin pkgs.openssl)
              pkgs.sops
            ];
          };
        }
      );
    };
}
