# cl-codec-kit

[![CI](https://github.com/nerima-lisp/cl-codec-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/nerima-lisp/cl-codec-kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-nerima--lisp.github.io-teal)](https://nerima-lisp.github.io/cl-codec-kit/)

A from-scratch, dependency-free Common Lisp codec library for converting
between strings and octet vectors, with a public API compatible in spirit
with the [babel](https://github.com/cl-babel/babel) library. See the
[documentation site](https://nerima-lisp.github.io/cl-codec-kit/) for why
this exists alongside SBCL's own `sb-ext:octets-to-string`.

## Quick Start

```lisp
(cl-codec-kit:string-to-octets "café" :encoding :utf-8)
;; => #(99 97 102 195 169)

(cl-codec-kit:octets-to-string #(99 97 102 195 169) :encoding :utf-8)
;; => "café"
```

## Install

Via a sibling checkout on `CL_SOURCE_REGISTRY` or ASDF's
`*central-registry*`:

```lisp
(asdf:load-system "cl-codec-kit")
```

## Documentation

Full documentation, including the API reference and the roadmap of which of
babel's ~46 encodings are implemented, lives at
<https://nerima-lisp.github.io/cl-codec-kit/>.

## Development

```sh
nix develop
nix flake check
```

## Contributing

See [CONTRIBUTING.md](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md).

## Support

See [SUPPORT.md](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).

## License

MIT. See [LICENSE](LICENSE).
