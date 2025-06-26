{
    inputs = {
        flake-parts.url = "github:hercules-ci/flake-parts";
        nixpkgs.url = "nixpkgs/nixos-25.05";
    };

    outputs = { flake-parts, ... } @ inputs:
        flake-parts.lib.mkFlake { inherit inputs; } {
            perSystem = { pkgs, ... }: {
                devShells.default = pkgs.mkShell {
                    packages = [ pkgs.dart ];
                };
            };

            systems = [ "x86_64-linux" ];
        };
}