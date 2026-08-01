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
instead, and decoding continues.

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
arguments, without retaining the encoded vector.

## Streaming

### `decode-prefix`

```lisp
(decode-prefix octets &key (start 0) end (encoding *default-encoding*))
```

Decode as much of `octets[start,end)` as forms complete characters. Returns
two values: the decoded string, and a fresh octet vector holding whatever
incomplete trailing sequence remains (empty when `octets` ends on a
character boundary). A genuinely invalid -- as opposed to merely truncated
-- sequence still signals normally.

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

`:utf-8`, `:utf-16`, `:utf-16be`, `:utf-16le`, `:utf-32`, `:utf-32be`,
`:utf-32le`, `:ucs-2`, `:ucs-2be`, `:ucs-2le`, `:ascii` (alias `:us-ascii`),
`:iso-8859-1` (aliases `:latin-1`, `:latin1`). See the
[roadmap](../project/roadmap.md) for encodings babel supports that are not
yet implemented here.
