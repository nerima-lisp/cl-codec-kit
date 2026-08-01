# Conditions

Every condition below is a subtype of `cl-codec-kit-error`. Catch that to
handle any failure from this library without naming each specific
condition.

| Condition | Signaled when |
|---|---|
| `unsupported-encoding` | `find-character-encoding` (or anything that calls it) is given an unregistered designator. Reader: `unsupported-encoding-designator`. |
| `invalid-leading-byte` | An octet that starts a character does not match any valid leading-byte pattern for the encoding. Readers: `invalid-leading-byte-position`, `invalid-leading-byte-octet`. |
| `invalid-continuation-byte` | A byte that should continue a multi-byte sequence does not match the continuation-byte pattern. Readers: `invalid-continuation-byte-position`, `invalid-continuation-byte-octet`. |
| `overlong-sequence` | A multi-byte sequence encodes a code point using more octets than its minimal encoding requires. Reader: `overlong-sequence-position`. |
| `surrogate-code-point` | A decoder assembles or encounters a code point in the UTF-16 surrogate range (U+D800-U+DFFF) where that range is never valid on its own. Readers: `surrogate-code-point-position`, `surrogate-code-point-value`. |
| `code-point-too-large` | A decoder assembles a code point above U+10FFFF. Readers: `code-point-too-large-position`, `code-point-too-large-value`. |
| `truncated-sequence` | A multi-byte sequence's leading byte/unit is valid but the buffer ends before its continuation bytes/units do. `decode-prefix` catches this specifically to split a buffer at a character boundary. Reader: `truncated-sequence-position`. |
| `unencodable-character` | `string-to-octets` (or `string-size-in-octets`) is asked to encode a character outside the encoding's codespace. Readers: `unencodable-character-char`, `unencodable-character-encoding`. |

Every position-bearing condition above names its slot `position` and can be
inspected uniformly with `(slot-value condition 'position)`, which is what
`decode-prefix` and `octets-to-string`'s lenient mode both rely on to stay
encoding-generic.
