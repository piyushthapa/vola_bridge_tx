{
  description = "Flake to setup Elixir Dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Elixir & Erlang
            beamMinimal28Packages.elixir_1_19
            beamMinimal28Packages.elixir-ls
            
            # Development tools
            git
            inotify-tools  # For Phoenix live reload
            glibcLocales
            cargo
            rustc
            libtool
            autoconf
            automake
            libsodium
          ];

          shellHook = ''
            # Mix setup
            export MIX_HOME="$PWD/.nix-mix"
            export HEX_HOME="$PWD/.nix-hex"
            mkdir -p $MIX_HOME $HEX_HOME
            
            # Add mix to PATH
            export PATH="$MIX_HOME/bin:$HEX_HOME/bin:$PATH"
            
          '';
          
        };
      }
    );
}
