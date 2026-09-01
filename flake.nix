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
    in
    {
      nixosModules = {
        base = ./modules/nixos/base.nix;
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
          inherit (host) system;
          specialArgs = {
            inherit
              host
              hostName
              inventory
              ;
            dircolorsSolarized = inputs.dircolors-solarized;
            inherit (self) nixosModules;
            nixpkgsSource = nixpkgs.outPath;
            system76HardwareModule = nixos-hardware.nixosModules.system76;
          };
          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
            (./hosts + "/${hostName}")
            {
              home-manager.sharedModules = [
                nixvim.homeModules.nixvim
                inputs.nix-index-database.homeModules.default
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
            packages = with pkgs; [
              age
              deadnix
              git
              nh
              nixfmt-tree
              openssl
              shellcheck
              sops
              statix
            ];
          };

          infra = pkgs.mkShellNoCC {
            packages = with pkgs; [
              ansible
              ansible-lint
            ];
          };
        }
      );
    };
}
