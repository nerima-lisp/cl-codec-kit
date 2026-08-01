# Conditions

Every condition below is a subtype of `cl-codec-kit-error`. Catch that to
handle any failure from this library without naming each specific
condition.

`decode-error` is a second base condition, between `cl-codec-kit-error` and
every condition below except `unsupported-encoding` and
`unencodable-character`. It carries the one slot every decoder-signaled
condition needs -- `position`, readable as `decode-error-position` -- and
exists so `decode-prefix` and `octets-to-string`'s lenient mode (`:errorp
nil`) can stay encoding-generic: both call `decode-error-position`, never a
condition-specific reader, so any decoder can participate in either simply
by signaling a `decode-error` subtype.

| Condition | Signaled when |
|---|---|
| `unsupported-encoding` | `find-character-encoding` (or anything that calls it) is given an unregistered designator. Reader: `unsupported-encoding-designator`. |
| `streaming-unsafe-encoding` | `decode-prefix`, or `octets-to-string` with `:errorp nil`, is asked to operate on a generic, byte-order-sensing designator (`:utf-16`, `:utf-32`, `:ucs-2`). See [Streaming and generic encodings](#streaming-and-generic-encodings) below. Reader: `streaming-unsafe-encoding-designator`. |
| `invalid-leading-byte` | An octet that starts a character does not match any valid leading-byte pattern for the encoding. Readers: `invalid-leading-byte-position`, `invalid-leading-byte-octet`. |
| `invalid-continuation-byte` | A byte that should continue a multi-byte sequence does not match the continuation-byte pattern. `position` names the *sequence's* start, not the offending byte's own offset -- `octet` carries that detail instead. Readers: `invalid-continuation-byte-position`, `invalid-continuation-byte-octet`. |
| `overlong-sequence` | A multi-byte sequence encodes a code point using more octets than its minimal encoding requires. Reader: `overlong-sequence-position`. |
| `surrogate-code-point` | A decoder assembles or encounters a code point in the UTF-16 surrogate range (U+D800-U+DFFF) where that range is never valid on its own. Readers: `surrogate-code-point-position`, `surrogate-code-point-value`. |
| `code-point-too-large` | A decoder assembles a code point above U+10FFFF. Readers: `code-point-too-large-position`, `code-point-too-large-value`. |
| `truncated-sequence` | A multi-byte sequence's leading byte/unit is valid but the buffer ends before its continuation bytes/units do. `decode-prefix` catches this specifically to split a buffer at a character boundary. Reader: `truncated-sequence-position`. |
| `unencodable-character` | `string-to-octets` (or `string-size-in-octets`) is asked to encode a character outside the encoding's codespace. `encoding` names the exact designator requested (e.g. `:utf-16be`, never the family name `:utf-16`). `position` is a `string` index, unlike `decode-error`'s octet-index `position` -- one CL character is always exactly one `string` index. Readers: `unencodable-character-char`, `unencodable-character-encoding`, `unencodable-character-position`. |

Every `decode-error` subtype's `position` names where the *failing character
starts* -- never a byte offset inside an otherwise-recognized sequence. That
invariant is what makes it always safe to redecode `octets[attempt-start,
position)` as a guaranteed-clean prefix, which both `decode-prefix` and the
lenient-mode recovery loop do.

## Streaming and generic encodings

`:utf-16`, `:utf-32`, and `:ucs-2` sense a byte-order mark wherever their
decoder is invoked, which is only meaningful at a stream's true start. A
single, one-shot `octets-to-string` call (the default `:errorp t`) is always
safe for them. `decode-prefix` and `octets-to-string`'s lenient mode both
call a decoder more than once, at internal resume offsets a real BOM would
never appear at -- so both refuse the three generic designators with
`streaming-unsafe-encoding` up front rather than risk silently flipping the
assumed byte order, or, for `:utf-32`, assembling a code point large enough
to signal `code-point-too-large` from data that was never actually invalid.
Use an explicit `:utf-16be`/`:utf-16le`/`:utf-32be`/etc. designator with
either function instead.
