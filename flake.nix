{
  description = "A from-scratch, dependency-free Common Lisp codec library with babel-compatible string/octet encoding support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-nix-forge,
      cl-weave,
      treefmt-nix,
      paredit-cli,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
    in
    cl-nix-forge.lib.${nixpkgs.lib.head systems}.mkPackageFlake {
      inherit self systems nixpkgs;

      pname = "cl-codec-kit";
      asd = ./cl-codec-kit.asd;
      root = ./.;

      meta = {
        description = "A from-scratch, dependency-free Common Lisp codec library with babel-compatible string/octet encoding support";
        homepage = "https://github.com/nerima-lisp/cl-codec-kit";
        license = nixpkgs.lib.licenses.mit;
      };

      lispCheckDependencies = ctx: [ cl-weave.packages.${ctx.system}.cl-weave ];

      docs.root = ./docs;

      devShellPackages = ctx: [ paredit-cli.packages.${ctx.system}.default ];

      treefmt.evalModule = treefmt-nix.lib.evalModule;
    };
}
