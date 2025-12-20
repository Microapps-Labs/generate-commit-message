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
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "gcm";
          version = "1.0.0";
          src = ./.;

          nativeBuildInputs = [
            pkgs.git
            pkgs.cacert
          ] ++ pkgs.lib.optionals (!isDarwin) [
            swiftPkgs.swift
            swiftPkgs.swiftpm
          ];

          # Allow network access for Swift Package Manager to fetch dependencies
          __noChroot = true;

          # On macOS, use system Swift toolchain for FoundationModels support
          __impureHostDeps = pkgs.lib.optionals isDarwin [
            "/usr/bin"
            "/usr/lib"
            "/System/Library/Frameworks"
            "/Library/Developer/CommandLineTools"
            "/Applications/Xcode.app"
            "/var/db/xcode_select_link"
          ];

          buildPhase = ''
            export HOME=$TMPDIR
            export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            export GIT_SSL_CAINFO=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          '' + (if isDarwin then ''
            # Use Xcode's Swift toolchain for FoundationModels support (Apple Intelligence)
            export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
            export PATH="/usr/bin:$PATH"
            # Unset nix's SDKROOT which points to an incompatible SDK version
            unset SDKROOT
            unset NIX_CFLAGS_COMPILE
            unset NIX_LDFLAGS
            /usr/bin/xcrun swift build -c release --disable-sandbox
          '' else ''
            swift build -c release
          '');

          # Disable fixup phase on Darwin as it uses GNU-style options
          dontFixup = isDarwin;

          installPhase = ''
            mkdir -p $out/bin
            cp .build/release/gcm $out/bin/
          '' + pkgs.lib.optionalString isDarwin ''
            # Re-sign the binary for macOS code signature validation
            /usr/bin/codesign --force --sign - $out/bin/gcm
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
          buildInputs = pkgs.lib.optionals (!isDarwin) [
            swiftPkgs.swift
            swiftPkgs.swiftpm
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
