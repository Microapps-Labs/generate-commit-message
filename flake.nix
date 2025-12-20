{
  description = "gcm - AI-powered git commit message generator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Check if we're on Darwin (macOS) or Linux
        isDarwin = pkgs.stdenv.isDarwin;

        # Use appropriate Swift package
        swiftPkgs = if isDarwin
          then pkgs.swiftPackages
          else pkgs.swiftPackages;

      in
      {
        packages.default = swiftPkgs.stdenv.mkDerivation {
          pname = "gcm";
          version = "1.0.0";
          src = ./.;

          nativeBuildInputs = [
            swiftPkgs.swift
            swiftPkgs.swiftpm
            pkgs.git
            pkgs.cacert
          ] ++ pkgs.lib.optionals isDarwin [
            pkgs.apple-sdk_15
          ];

          # Allow network access for Swift Package Manager to fetch dependencies
          __noChroot = true;

          buildPhase = ''
            export HOME=$TMPDIR
            export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            export GIT_SSL_CAINFO=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            swift build -c release
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp .build/release/gcm $out/bin/
          '';

          meta = with pkgs.lib; {
            description = "AI-powered git commit message generator";
            longDescription = ''
              A CLI tool that generates git commit messages using AI.
              On macOS 26+, uses Apple's on-device Foundation Models.
              On Linux or older macOS, uses OpenRouter/OpenAI API.
            '';
            homepage = "https://github.com/gcm-cli/gcm";
            license = licenses.mit;
            platforms = platforms.unix;
            mainProgram = "gcm";
          };
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = [
            swiftPkgs.swift
            swiftPkgs.swiftpm
          ] ++ pkgs.lib.optionals isDarwin [
            pkgs.apple-sdk_15
          ];

          shellHook = ''
            echo "gcm development environment"
            echo "Swift version: $(swift --version | head -1)"
            echo ""
            echo "Commands:"
            echo "  swift build      - Build the project"
            echo "  swift run gcm    - Run the CLI"
            echo "  swift test       - Run tests"
          '';
        };

        # For easy testing
        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/gcm";
        };
      }
    );
}
