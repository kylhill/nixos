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
    nixvim.url = "github:nix-community/nixvim/nixos-26.05";

    oh-my-bash = {
      url = "github:ohmybash/oh-my-bash";
      flake = false;
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
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.pang14 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
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

      checks.${system}.pang14 = self.nixosConfigurations.pang14.config.system.build.toplevel;
      formatter.${system} = pkgs.nixfmt;

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
          nixfmt
          openssl
          shellcheck
          sops
          statix
        ];
      };
    };
}
