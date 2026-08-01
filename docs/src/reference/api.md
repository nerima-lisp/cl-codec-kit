# API reference

## Conversion

### `octets-to-string`

```lisp
(octets-to-string octets &key (start 0) end (encoding *default-encoding*)
                              (errorp t) (replacement (code-char #x1a)))
```

Decode `octets[start,end)` as `encoding` into a string. When `errorp` is
true (the default), an invalid or truncated sequence signals the
corresponding condition (see [Conditions](conditions.md)). When `errorp` is
`nil`, each invalid or truncated sequence is replaced by `replacement`
instead, and decoding continues -- except for `:utf-16`/`:utf-32`/`:ucs-2`,
which signal `streaming-unsafe-encoding` instead; see
[Streaming and generic encodings](conditions.md#streaming-and-generic-encodings).

### `string-to-octets`

```lisp
(string-to-octets string &key (start 0) end (encoding *default-encoding*))
```

Encode `string[start,end)` as `encoding` into a fresh `(unsigned-byte 8)`
vector. Always signals `unencodable-character` on a character `encoding`
cannot represent -- there is no lenient mode on encode.

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
                                   (replacement (code-char #x1a)))
```

Like `decode-prefix`, but a genuinely invalid sequence is replaced by
`replacement` and decoding continues, matching `octets-to-string`'s `errorp
nil` mode -- only a truncated sequence at the very end of `octets[start,end)`
is still held back as `decode-prefix` does. Neither `decode-prefix` nor
`octets-to-string` alone provides this combination: a caller decoding a
stream under a "replace invalid, but don't corrupt a character split across
a chunk boundary" policy needs both at once. Signals
`streaming-unsafe-encoding` for `:utf-16`/`:utf-32`/`:ucs-2`, for the same
reason `decode-prefix` does.

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
its registered encoding, or signal `unsupported-encoding`.

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
