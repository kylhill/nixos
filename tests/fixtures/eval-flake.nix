{
  outputs =
    { self }:
    {
      lib.validation = {
        inherit (self) homeConfigurations nixosConfigurations devShells;
      };
      homeConfigurations = {
        good = {
          activationPackage.drvPath = "good-home";
          config = {
            programs.git.enable = true;
            home.homeDirectory = "/fixture/home";
          };
        };
        other-home.activationPackage.drvPath = "hyphenated-home";
        unrelated = throw "unselected home forced";
      };
      nixosConfigurations = {
        fixture.config = {
          services.openssh.enable = false;
          assertions = [ ];
          home-manager.users.user = {
            home.activationPackage.drvPath = "integrated-home";
            programs.git.enable = true;
          };
        };
        broken.config.assertions = [
          {
            assertion = false;
            message = "fixture assertion failure";
          }
        ];
      };
      devShells.x86_64-linux.default.drvPath = "development-shell";
    };
}
