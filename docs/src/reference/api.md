# API reference

## Conversion

### `octets-to-string`

```lisp
(octets-to-string octets &key (start 0) end (encoding *default-encoding*)
                              (errorp t) replacement)
```

Decode `octets[start,end)` as `encoding` into a string. When `errorp` is
true (the default), an invalid or truncated sequence signals the
corresponding condition (see [Conditions](conditions.md)). When `errorp` is
`nil`, each invalid or truncated sequence is replaced by `replacement`
instead, and decoding continues -- except for `:utf-16`/`:utf-32`/`:ucs-2`,
which signal `streaming-unsafe-encoding` instead; see
[Streaming and generic encodings](conditions.md#streaming-and-generic-encodings).

`replacement` `nil` (the default) means `encoding`'s own
[default replacement](#the-default-replacement-is-per-encoding).

### `string-to-octets`

```lisp
(string-to-octets string &key (start 0) end (encoding *default-encoding*)
                              (errorp t) replacement)
```

Encode `string[start,end)` as `encoding` into a fresh `(unsigned-byte 8)`
vector. When `errorp` is true (the default), a character `encoding` cannot
represent signals `unencodable-character` (see [Conditions](conditions.md)).
When `errorp` is `nil`, each unencodable character is replaced by
`replacement`'s own encoding instead, and encoding continues -- resuming
never needs a resync width the way lenient decoding does, since one CL
character is always exactly one `string` index. If `replacement` itself is
not representable in `encoding`, `unencodable-character` propagates rather
than looping.

`replacement` `nil` (the default) means `encoding`'s own
[default replacement](#the-default-replacement-is-per-encoding), which is
always representable in that encoding and so never trips that last case.

### `string-size-in-octets`

```lisp
(string-size-in-octets string &key (start 0) end (encoding *default-encoding*))
```

Return how many octets `string-to-octets` would produce for the same
arguments. This calls `string-to-octets` internally and discards the result
rather than measuring without allocating -- it exists for API parity with
babel's `string-size-in-octets`, not as a faster alternative to encoding.

## Streaming

### `decode-prefix`

```lisp
(decode-prefix octets &key (start 0) end (encoding *default-encoding*))
```

Decode as much of `octets[start,end)` as forms complete characters. Returns
two values: the decoded string, and a fresh octet vector holding whatever
incomplete trailing sequence remains (empty when `octets` ends on a
character boundary). A genuinely invalid -- as opposed to merely truncated
-- sequence still signals normally. Signals `streaming-unsafe-encoding` for
`:utf-16`/`:utf-32`/`:ucs-2`; see
[Streaming and generic encodings](conditions.md#streaming-and-generic-encodings).

### `lenient-decode-prefix`

```lisp
(lenient-decode-prefix octets &key (start 0) end (encoding *default-encoding*)
                                   replacement)
```

Like `decode-prefix`, but a genuinely invalid sequence is replaced by
`replacement` and decoding continues, matching `octets-to-string`'s `errorp
nil` mode -- only a truncated sequence at the very end of `octets[start,end)`
is still held back as `decode-prefix` does. Neither `decode-prefix` nor
`octets-to-string` alone provides this combination: a caller decoding a
stream under a "replace invalid, but don't corrupt a character split across
a chunk boundary" policy needs both at once. Signals
`streaming-unsafe-encoding` for `:utf-16`/`:utf-32`/`:ucs-2`, for the same
reason `decode-prefix` does. `replacement` `nil` (the default) means
`encoding`'s own [default replacement](#the-default-replacement-is-per-encoding).

## The default replacement is per-encoding

`octets-to-string`, `string-to-octets`, and `lenient-decode-prefix` all
substitute the same character when you leave `:replacement` out, and which
character that is depends on the encoding:

| Encoding | Default `replacement` |
|---|---|
| `:utf-8` | U+FFFD REPLACEMENT CHARACTER |
| `:utf-16`, `:utf-16be`, `:utf-16le` | U+FFFD REPLACEMENT CHARACTER |
| `:utf-32`, `:utf-32be`, `:utf-32le` | U+FFFD REPLACEMENT CHARACTER |
| `:ucs-2`, `:ucs-2be`, `:ucs-2le` | U+FFFD REPLACEMENT CHARACTER |
| `:ascii` | U+001A SUB |
| `:iso-8859-1` | U+001A SUB |

Two independent reasons for the split:

- **It is what babel does.** babel's Unicode codecs pass `+repl+` (`#xFFFD`)
  to every substitution site; its single-octet codecs, which `:ascii` and
  `:iso-8859-1` are both built from, pass
  `+default-substitution-code-point+` (`#x1A`) instead. babel's exported
  `enc-default-replacement` slot looks authoritative and is not -- no code
  path in babel ever reads it, and for `:utf-8` it disagrees with what
  babel's own decoder substitutes.
- **U+FFFD is not representable in `:ascii` or `:iso-8859-1`.** A
  library-wide U+FFFD default would make `string-to-octets :errorp nil`
  signal `unencodable-character` for the replacement itself under those two.

### `character-encoding-default-replacement`

```lisp
(character-encoding-default-replacement encoding-object)
```

Return the character above for an encoding object obtained from
`find-character-encoding`. Returns a **character**, where babel's
similarly-named `enc-default-replacement` returns a code point.

### Migrating from babel, or from cl-codec-kit before 0.4.0

Before 0.4.0 this library defaulted to U+001A for every encoding, and
documented that as matching babel. That was wrong for UTF-8, the default
encoding: babel substitutes U+FFFD there. Any call that decoded UTF-8 with
`:errorp nil` and no `:replacement` changes behavior on upgrade.

If you care which character appears, pass `:replacement` explicitly rather
than depending on any default:

```lisp
(cl-codec-kit:octets-to-string buffer :errorp nil
                               :replacement #\REPLACEMENT_CHARACTER)
```

## Registry

### `*default-encoding*`

The encoding used when `:encoding` is omitted. Defaults to `:utf-8`.

### `list-character-encodings`

Return a list of every canonical encoding name currently registered.

### `find-character-encoding`

```lisp
(find-character-encoding designator)
```

Resolve `designator` (a keyword naming an encoding or one of its aliases) to
its registered encoding, or signal `unsupported-encoding`. The result is
what `character-encoding-default-replacement` takes.

## Supported encodings

| Encoding | Aliases |
|---|---|
| `:utf-8` | -- |
| `:utf-16` | -- (generic, senses a byte-order mark on decode; always emits one on encode) |
| `:utf-16be` | `:utf-16/be` |
| `:utf-16le` | `:utf-16/le` |
| `:utf-32` | `:ucs-4` |
| `:utf-32be` | `:utf-32/be`, `:ucs-4be`, `:ucs-4/be` |
| `:utf-32le` | `:utf-32/le`, `:ucs-4le`, `:ucs-4/le` |
| `:ucs-2` | -- (generic, senses a byte-order mark on decode; always emits one on encode) |
| `:ucs-2be` | `:ucs-2/be` |
| `:ucs-2le` | `:ucs-2/le` |
| `:ascii` | `:us-ascii` |
| `:iso-8859-1` | `:latin-1`, `:latin1` |

See the [roadmap](../project/roadmap.md) for encodings babel supports that
are not yet implemented here.
