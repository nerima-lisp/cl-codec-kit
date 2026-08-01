# Getting started

## Install

Via a sibling checkout on `CL_SOURCE_REGISTRY` or ASDF's `*central-registry*`:

```lisp
(asdf:load-system "cl-codec-kit")
```

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
`:errorp nil` to replace each bad sequence with a replacement character
(`#x1A` by default, matching babel's own default) and keep decoding:

```lisp
(cl-codec-kit:octets-to-string #(65 128 66) :errorp nil)
;; => "A<SUB>B", where <SUB> is (code-char #x1a)
```

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
