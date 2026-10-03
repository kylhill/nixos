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
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    solarized-nvim = {
      url = "github:maxmx03/solarized.nvim";
      flake = false;
    };
  };

  outputs =
    inputs@{
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
      shellFiles = builtins.filter (file: file != "") (
        nixpkgs.lib.splitString "\n" (builtins.readFile ./tests/shell-files)
      );
      checkSource =
        files:
        nixpkgs.lib.fileset.toSource {
          root = ./.;
          fileset = nixpkgs.lib.fileset.unions (map (file: ./. + "/${file}") files);
        };
      shellSource = checkSource (shellFiles ++ [ "tests/shell-files" ]);
      nixSource = nixpkgs.lib.fileset.toSource {
        root = ./.;
        fileset = nixpkgs.lib.fileset.fileFilter (file: file.hasExt "nix") ./.;
      };
      mkPkgs =
        nixpkgsInput: system:
        import nixpkgsInput {
          inherit system;
          config.allowUnfreePredicate =
            package: builtins.elem (nixpkgs.lib.getName package) inventory.sharedUnfreePackages;
        };
      mkHost =
        hostName: host:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            inherit (inventory) sharedUnfreePackages;
          };
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
          pkgs = mkPkgs inputs.nixpkgs-unstable home.system;
          extraSpecialArgs = {
            inherit inputs;
            homeIdentity = {
              inherit (inventory.user) fullName email;
            };
            networkHosts = inventory.network.hosts;
          };
          modules = [
            (./homes + "/${homeName}.nix")
            {
              home = {
                username = inventory.user.name;
                inherit (home) homeDirectory stateVersion;
              };
              services.home-manager.autoExpire = {
                enable = true;
                frequency = "weekly";
                timestamp = "-7 days";
                store.cleanup = true;
              };
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
            let
              source =
                if suite == "runner" then
                  shellSource
                else if suite == "apply" then
                  checkSource [
                    "apply.sh"
                    "tests/test-apply.sh"
                    "tests/fixtures/apply-tool"
                  ]
                else
                  checkSource [
                    "windows"
                    "tests/test-windows.ps1"
                    "tests/test-windows.sh"
                  ];
            in
            pkgs.runCommand "${suite}-fixtures"
              {
                nativeBuildInputs =
                  if suite == "windows" then
                    [
                      pkgs.bash
                      pkgs.coreutils
                      pkgs.powershell
                    ]
                  else
                    [
                      pkgs.bash
                      pkgs.coreutils
                      pkgs.git
                      pkgs.gnugrep
                    ];
              }
              ''
                bash ${source}/tests/test-${suite}.sh
                touch $out
              '';
        in
        {
          apply-fixtures = fixtureCheck "apply";
          runner-fixtures = fixtureCheck "runner";
          windows-fixtures = fixtureCheck "windows";

          formatting =
            pkgs.runCommand "nixfmt-check"
              {
                nativeBuildInputs = [
                  pkgs.findutils
                  pkgs.nixfmt
                ];
              }
              ''
                find ${nixSource} -type f -name '*.nix' -exec nixfmt --check {} +
                touch $out
              '';

          statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
            statix check ${nixSource}
            touch $out
          '';

          deadnix = pkgs.runCommand "deadnix-check" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
            deadnix --fail ${nixSource}
            touch $out
          '';

          shellcheck = pkgs.runCommand "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
            shellcheck ${nixpkgs.lib.escapeShellArgs (map (file: "${shellSource}/${file}") shellFiles)}
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
              (pkgs.lib.getBin pkgs.jq)
              pkgs.nixfmt
              pkgs.nixfmt-tree
              pkgs.ripgrep
              (pkgs.lib.getBin pkgs.powershell)
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
