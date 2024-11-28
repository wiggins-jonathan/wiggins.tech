{
  description = "Development environment with dependencies for wiggins.tech";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = ["x86_64-linux" "x86_64-darwin"];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
    in {
      devShells = forEachSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            go
            hugo
          ];

          shellHook = ''
            echo "$(go version)"
            echo "$(hugo version)"
          '';
        };
      });
    };
}
