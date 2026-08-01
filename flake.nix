{
  description = "A from-scratch, dependency-free Common Lisp codec library with babel-compatible string/octet encoding support";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The org's own "crane for Common Lisp/ASDF": turns this repository's
    # .asd into a Nix derivation and generates the whole PACKAGE_STANDARD.md
    # output table (packages/checks/apps/devShells/formatter/overlays) from
    # one mkPackageFlake call below, instead of hand-rolling each of them.
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # cl-weave is a test-only dependency (see cl-codec-kit.asd's
    # cl-codec-kit/test system), reached through lispCheckDependencies below
    # -- never through the package's own lispDependencies, so a consumer
    # building only the library never fetches or builds it.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-nix-forge,
      cl-weave,
      treefmt-nix,
      ...
    }:
    let
      # The only platform this repository verifies. See PACKAGE_STANDARD.md,
      # section "systems": dropping aarch64-darwin also drops
      # devShells.aarch64-darwin, so `nix develop`/`nix build` do not work on
      # macOS; development happens on Linux.
      systems = [
        "x86_64-linux"
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

      # cl-weave's own flake exports the ASDF system itself as
      # packages.<system>.cl-weave, distinct from packages.default (its
      # delivered CLI) -- taking the CLI here would pull in a binary the test
      # suite never runs.
      lispCheckDependencies = ctx: [ cl-weave.packages.${ctx.system}.cl-weave ];

      docs.root = ./docs;

      # PACKAGE_STANDARD.md scopes treefmt to Nix and only Nix (the default
      # module mkPackageFlake applies when `module` is omitted): a YAML
      # formatter mangles GitHub Actions' `on:` key, and reformatting the
      # whole docs tree on every touch would drown real review in noise.
      treefmt.evalModule = treefmt-nix.lib.evalModule;
    };
}
