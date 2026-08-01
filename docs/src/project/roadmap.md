# Roadmap

## Implemented

The Unicode encoding family, plus the two simplest legacy encodings:

- UTF-8, UTF-16 (generic/BE/LE), UTF-32 (generic/BE/LE), UCS-2 (generic/BE/LE)
- ASCII, ISO-8859-1 (Latin-1)
- `decode-prefix`: an encoding-generic streaming partial-decode primitive
  babel itself does not provide (see the [home page](../index.md))
- A package-specific condition hierarchy with position-based introspection
- Lenient decoding (`:errorp nil`) with a configurable replacement character

This set covers every encoding actually used today across `cl-tmux`,
`cl-tty-kit`, and `cl-process-kit` (all UTF-8 only), plus the rest of the
Unicode family for babel-compatibility.

## Deliberately not yet implemented

babel supports roughly 46 encodings in total. The following are **not**
implemented here, by explicit scope decision rather than oversight:

- **UTF-8B** (babel's lossless, always-succeeds UTF-8 variant using
  surrogate-escape for invalid bytes). No current consumer needs it.
- **ISO-8859-2 through ISO-8859-16** (13 more Latin/Cyrillic/Greek/Hebrew/
  Arabic variants).
- **Windows code pages**: CP1250 through CP1258, CP437.
- **EBCDIC and EBCDIC-INT.**
- **GBK** (Chinese), **ISO-2022-JP**, **EUC-JP**, **CP932** (Shift-JIS
  family), **KOI8-R/RU/U** (Cyrillic), **KSC-5601** (Korean).

These are deferred rather than fabricated because most require large,
hand-verified mapping tables (hundreds to thousands of entries each) that
would be transcribed from a reference source rather than genuinely
implemented from first principles, and none has a current consumer in this
org. Adding one needs: a new `src/<encoding>.lisp` file that calls
`define-encoding` (see `src/registry.lisp`) with the correct `:resync-width`
(1 for byte-oriented, or the fixed code-unit width in octets otherwise) and
`:bom-sensing-p` (only for a *generic*, byte-order-sensing designator --
see [Streaming and generic encodings](../reference/conditions.md#streaming-and-generic-encodings)),
following the shape of `src/ascii.lisp`/`src/iso-8859-1.lisp` for a
fixed-width encoding or `src/utf-8.lisp` for a variable-width one; and an
entry in `cl-codec-kit.asd`'s `:components` list, in `:serial` load order
after `registry`.

## Planned follow-up work (outside this repository)

Per the requirements defined for this project:

1. Migrate `cl-tty-kit`'s `src/utf8.lisp` to depend on and delegate to
   `cl-codec-kit`.
2. Migrate `cl-process-kit`'s `capture.lisp`/`pty.lisp`/`copier.lisp` UTF-8
   handling onto `cl-codec-kit`.
3. Migrate `cl-tmux` off its external `babel` dependency.
