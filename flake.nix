{
  description = "Doom2D flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-github-actions.url = "github:nix-community/nix-github-actions";

    doom2df-res = {
      url = "github:Doom2D/DF-Res";
      flake = false;
    };
    d2df-sdl = {
      url = "git://repo.or.cz/d2df-sdl.git?submodules=1";
      flake = false;
    };
    d2df-editor = {
      url = "git://repo.or.cz/d2df-editor.git?submodules=1";
      flake = false;
    };
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    nix-github-actions,
    doom2df-res,
    d2df-sdl,
    d2df-editor,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config = {
          android_sdk.accept_license = true;
          allowUnfree = true;
          allowUnsupportedSystem = true;
        };
        overlays = [
          (final: prev: {
            fpc = prev.callPackage fpcPkgs.fpc {
              fpc = prev.fpc;
              archsAttrs = {};
            };
            dfwad = final.callPackage d2dfPkgs.dfwad {};
          })
        ];
      };
      lib = pkgs.lib;
      fpcPkgs = import ./fpc;
      d2dfPkgs = import ./game;
      bundles = import ./game/bundle {
        inherit (pkgs) callPackage;
      };
      assets = import ./game/assets {
        inherit (pkgs) callPackage;
      };
    in {
      dfInputs = {
        inherit d2df-sdl d2df-editor doom2df-res;
      };

      checks = lib.mapAttrs (n: v: v.drv) (lib.foldl (acc: x: acc // x) {} (lib.map (x: x.executables) (lib.attrValues self.outputs'.${system})));

      assets = assets;

      executables = import ./packages/executables.nix {
        inherit pkgs lib fpcPkgs d2dfPkgs;
        inherit d2df-sdl d2df-editor;
      };

      outputs' = import ./packages {
        inherit lib;
        inherit (pkgs) callPackage;
        inherit (d2dfPkgs) buildWad;
        inherit doom2df-res d2df-editor;
        inherit (assets) mkAssetsPath dirtyAssets androidRoot;
        androidRes = assets.androidIcons;
        inherit (bundles) mkExecutablePath mkGamePath mkAndroidApk;
        executablesAttrs = self.executables.${system};
      };

      devShell = with pkgs;
        mkShell rec {
          buildInputs = [
            bash
            alejandra
            nixd
            jq
            _7zz
            git
            findutils
          ];
        };
    })
    // {
      githubActions = nix-github-actions.lib.mkGithubMatrix {
        # Inherit GHA actions matrix from a subset of platforms supported by hosted runners
        checks = {
          inherit (self.checks) x86_64-linux;
        };
      };
    };
}
