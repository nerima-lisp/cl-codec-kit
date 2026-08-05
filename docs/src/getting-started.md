# Getting started

## Install

Via a sibling checkout on `CL_SOURCE_REGISTRY` or ASDF's `*central-registry*`:

```lisp
(asdf:load-system "cl-codec-kit")
```

## Running the tests

```sh
sbcl --script run-tests.lisp
```

expects a sibling `../cl-weave/` checkout (the test system's only
dependency; see `cl-codec-kit.asd`). To also measure coverage with SBCL's
`sb-cover` -- cl-weave's own built-in integration, not a hand-rolled setup --
pass `:coverage t` to `cl-codec-kit/test:run-tests`. SB-COVER only
instruments code compiled *after* `sb-cover:store-coverage-data` is
proclaimed, so this needs a fresh SBCL process with that proclaim in place
before `cl-codec-kit` is compiled -- `run-tests.lisp` does not do this, and
neither does simply calling `(asdf:load-system "cl-codec-kit/test")` in a
process where the system was already loaded:

```lisp
(require :asdf)
(require :sb-cover)
(declaim (optimize sb-cover:store-coverage-data))
(asdf:load-system "cl-codec-kit/test" :force :all)
(cl-codec-kit/test:run-tests :coverage t)
;; writes coverage-report/cover-index.html and cl-codec-kit.coverage
```

`:coverage` defaults to `nil` so a plain `sbcl --script run-tests.lisp` (and
therefore `asdf:test-system`/`nix flake check`) stays fast and produces no
extra artifacts.

## Basic usage

```lisp
(cl-codec-kit:string-to-octets "café" :encoding :utf-8)
;; => #(99 97 102 195 169)

(cl-codec-kit:octets-to-string #(99 97 102 195 169) :encoding :utf-8)
;; => "café"
```

`:encoding` defaults to `cl-codec-kit:*default-encoding*`, which is `:utf-8`.

## Lenient decoding

By default, an invalid or truncated byte sequence signals a condition. Pass
`:errorp nil` to replace each bad sequence with a replacement character and
keep decoding:

```lisp
(cl-codec-kit:octets-to-string #(65 128 66) :errorp nil)
;; => "A<U+FFFD>B"  ; :utf-8, so the replacement is U+FFFD
```

The replacement is **per encoding**, not one library-wide constant. Omitting
`:replacement` gives you U+FFFD (REPLACEMENT CHARACTER) under any
Unicode-family encoding, and U+001A (SUB) under `:ascii` and `:iso-8859-1`,
which cannot represent U+FFFD at all:

```lisp
(cl-codec-kit:octets-to-string #(65 255 66) :encoding :ascii :errorp nil)
;; => "A<SUB>B"  ; (code-char #x1a)
```

This is the split babel makes, and it is the value babel's codecs actually
substitute -- not the value of babel's `enc-default-replacement` slot, which
nothing in babel reads. Pass `:replacement` explicitly whenever the choice
matters to you rather than relying on either library's default:

```lisp
(cl-codec-kit:octets-to-string #(65 128 66) :errorp nil
                               :replacement #\REPLACEMENT_CHARACTER)
```

!!! warning "Changed in 0.4.0"
    Before 0.4.0 the default was U+001A for *every* encoding, including
    UTF-8. Code that decoded UTF-8 leniently without passing `:replacement`
    silently changes behavior on upgrade -- and, if it renders the result,
    changes from an invisible C0 control character to a visible glyph. Pass
    `:replacement (code-char #x1a)` to keep the old value.

## Streaming decode

`decode-prefix` decodes as much of a buffer as forms complete characters and
returns the undecoded trailing octets separately -- the primitive to reach
for when octets arrive in chunks (a socket, a PTY) and a multibyte character
might be split across a read boundary:

```lisp
(cl-codec-kit:decode-prefix #(228 189 240) :encoding :utf-8)
;; => "你", #()   ; if #(228 189 240) is exactly one complete character

(cl-codec-kit:decode-prefix #(65 228 189) :encoding :utf-8)
;; => "A", #(228 189)   ; the trailing 2 octets are an incomplete character
```

See the [API reference](reference/api.md) for the full function list and the
[roadmap](project/roadmap.md) for which encodings are implemented.
