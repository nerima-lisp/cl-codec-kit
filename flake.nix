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
      url = "github:nerima-lisp/cl-nix-forge/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # cl-weave is a test-only dependency (see cl-codec-kit.asd's
    # cl-codec-kit/test system), reached through lispCheckDependencies below
    # -- never through the package's own lispDependencies, so a consumer
    # building only the library never fetches or builds it.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.1.4";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The structural-refactoring CLI contributors run by hand. Consumed only
    # as an interactive devShell package, never as a Lisp dependency.
    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.4.0";
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
      # x86_64-linux is what CI gates; aarch64-darwin is the development
      # machine. Every per-system output -- packages, checks, apps AND devShells
      # -- comes from this one list, so leaving aarch64-darwin out takes `nix
      # build` and `nix develop` off the development machine as well. That trade
      # was made on 2026-08-01 and reverted on 2026-08-02; aarch64-darwin carries
      # no CI gate, which PACKAGE_STANDARD.md's "systems" section accepts
      # explicitly. aarch64-linux and x86_64-darwin are nobody's verification and
      # are not declared.
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

      # cl-weave's own flake exports the ASDF system itself as
      # packages.<system>.cl-weave, distinct from packages.default (its
      # delivered CLI) -- taking the CLI here would pull in a binary the test
      # suite never runs.
      lispCheckDependencies = ctx: [ cl-weave.packages.${ctx.system}.cl-weave ];

      docs.root = ./docs;

      # Interactive-only: pulled into `nix develop`'s PATH via `mkDevShell`'s
      # `extraPackages`, never into the build (`lispDependencies`/
      # `lispCheckDependencies` above are what those actually gate).
      #
      # `lib.optional` guards `aarch64-darwin`: paredit-cli's v1.4.0 tag only
      # publishes `packages.x86_64-linux` (aarch64-darwin support landed on
      # its default branch after that tag was cut) -- an unconditional
      # reference here would make `nix develop`/`nix flake check` fail on
      # the development machine specifically. Drop this guard once a
      # paredit-cli tag ships aarch64-darwin packages.
      devShellPackages =
        ctx:
        nixpkgs.lib.optional (
          paredit-cli.packages ? ${ctx.system}
        ) paredit-cli.packages.${ctx.system}.default;

      # PACKAGE_STANDARD.md scopes treefmt to Nix and only Nix (the default
      # module mkPackageFlake applies when `module` is omitted): a YAML
      # formatter mangles GitHub Actions' `on:` key, and reformatting the
      # whole docs tree on every touch would drown real review in noise.
      treefmt.evalModule = treefmt-nix.lib.evalModule;
    };
}
