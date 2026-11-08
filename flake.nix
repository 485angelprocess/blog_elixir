{
  description = "Nix dev environment for embroider";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/8c50a710ddca43d7a530fb805ad55bde8d0141c5";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells."${system}".default = pkgs.mkShell {
        packages = with pkgs; [
          git
          elixir
          mix2nix
        ];

        shellHook = "";
      };
    };
}
