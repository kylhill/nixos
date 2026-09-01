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

    nixos-hardware.url = "github:NixOS/nixos-hardware";
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
      hostName = "pang14";
      host = inventory.hosts.${hostName};
      inherit (host) system;
      pkgs = import nixpkgs { inherit system; };
    in
    {
      nixosModules = {
        base = ./modules/nixos/base.nix;
        gnome = ./modules/nixos/desktop-gnome.nix;
        laptop = ./modules/nixos/laptop.nix;
        system76 = ./modules/nixos/system76.nix;
        zfs = ./modules/nixos/storage-zfs.nix;
      };

      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit
            host
            hostName
            inputs
            inventory
            ;
        };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          nixos-hardware.nixosModules.system76
          ./hosts/pang14
          {
            home-manager.sharedModules = [ nixvim.homeModules.nixvim ];
          }
        ];
      };

      checks.${system} = {
        ${hostName} = self.nixosConfigurations.${hostName}.config.system.build.toplevel;

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
      };
      formatter.${system} = pkgs.nixfmt-tree;

      apps.${system}.disko = {
        type = "app";
        program = "${disko.packages.${system}.disko}/bin/disko";
        meta.description = "Declaratively partition and format disks with Disko";
      };

      devShells.${system}.default = pkgs.mkShellNoCC {
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
    };
}
