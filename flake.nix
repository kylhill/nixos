{
  description = "Kyle Hill's NixOS infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

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

    dircolors-solarized = {
      url = "github:seebi/dircolors-solarized";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      disko,
      sops-nix,
      nixos-hardware,
      nixvim,
      ...
    }:
    let
      inventory = import ./lib/inventory.nix;
      supportedSystems = nixpkgs.lib.unique (
        map (host: host.system) (builtins.attrValues inventory.hosts)
      );
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
      hardwareModules = {
        system76 = nixos-hardware.nixosModules.system76;
      };
    in
    {
      nixosModules = {
        base = ./modules/nixos/base.nix;
        infrastructure = ./modules/nixos/infrastructure.nix;
        laptop = ./modules/nixos/laptop.nix;
        networkmanager-vpn = ./modules/nixos/networkmanager-vpn.nix;
        networkmanager-wifi = ./modules/nixos/networkmanager-wifi.nix;
        secrets = ./modules/nixos/secrets.nix;
        workstation-zfs = ./modules/nixos/workstation-zfs.nix;
        system76 = ./modules/nixos/system76.nix;
        user-kyleh = ./modules/nixos/user-kyleh.nix;
        workstation = ./modules/nixos/workstation.nix;
      };

      nixosConfigurations = nixpkgs.lib.mapAttrs (
        hostName: host:
        nixpkgs.lib.nixosSystem {
          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
            self.nixosModules.infrastructure
          ]
          ++ map (name: hardwareModules.${name}) (host.hardwareModules or [ ])
          ++ [
            (./hosts + "/${hostName}")
            {
              infrastructure = {
                inherit host;
                inherit (inventory) user network;
              };
              networking.hostName = hostName;
              nixpkgs.hostPlatform = host.system;
              nix.registry.nixpkgs.flake = inputs.nixpkgs;
              nix.nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];
              home-manager.sharedModules = [
                nixvim.homeModules.nixvim
                inputs.nix-index-database.homeModules.default
                {
                  infrastructure.sources.dircolorsSolarized = inputs.dircolors-solarized;
                }
              ];
            }
          ];
        }
      ) inventory.hosts;

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          formatting = pkgs.runCommand "nixfmt-check" { nativeBuildInputs = [ pkgs.nixfmt-tree ]; } ''
            cd ${self}
            treefmt --ci
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
              ${self}/scripts/install-host-key \
              ${self}/scripts/install-preflight
            touch $out
          '';
        }
      );
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);

      apps = forAllSystems (system: {
        disko = {
          type = "app";
          program = "${disko.packages.${system}.disko}/bin/disko";
          meta.description = "Declaratively partition and format disks with Disko";
        };
      });

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
              pkgs.git
              pkgs.nh
              pkgs.nixfmt-tree
              pkgs.openssl
              pkgs.shellcheck
              pkgs.sops
              pkgs.statix
            ];
          };

        }
      );
    };
}
