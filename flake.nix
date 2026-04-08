{
  description = "Decapod: daemonless, local-first control plane for multi-agent work";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
      rust-overlay,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };
        runtimeLibs = with pkgs; [
          sqlite
        ];
        toolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "clippy"
            "rustfmt"
          ];
        };
      in
      {
        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "decapod";
          version =
            let
              cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
            in
            cargoToml.package.version;

          src = pkgs.lib.cleanSource ./.;

          cargoLock.lockFile = ./Cargo.lock;

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          buildInputs = with pkgs; [
            sqlite
          ];

          meta = {
            description = "Daemonless, local-first control plane for multi-agent work";
            homepage = "https://github.com/DecapodLabs/decapod";
            license = pkgs.lib.licenses.mit;
            mainProgram = "decapod";
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            clang
            git
            lld
            nixfmt-rfc-style
            openssh
            pkg-config
            sqlite
            toolchain
          ];

          shellHook = ''
            export CARGO_TERM_COLOR=always
            export CARGO_INCREMENTAL=0
            export CARGO_NET_RETRY=10
            export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            if [ "$(uname -s)" = "Linux" ]; then
              export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=clang
              export RUSTFLAGS="-C link-arg=-fuse-ld=lld''${RUSTFLAGS:+ $RUSTFLAGS}"
            fi
          '';
        };

        devShells.ci = self.devShells.${system}.default;
      }
    );
}
