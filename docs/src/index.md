# cl-codec-kit

A from-scratch, dependency-free Common Lisp codec library for converting
between strings and octet vectors, with a public API compatible in spirit
with the [babel](https://github.com/cl-babel/babel) library it exists to
eventually let [cl-tmux](https://github.com/nerima-lisp/cl-tmux) stop
depending on.

## Why not just wrap `sb-ext:octets-to-string`?

SBCL's own `sb-ext:octets-to-string`/`string-to-octets` already cover UTF-8
encode/decode competently. cl-codec-kit exists for two reasons that are
independent of that fact:

1. **A generalized streaming primitive neither babel nor SBCL provide.**
   [`cl-tty-kit`](https://github.com/nerima-lisp/cl-tty-kit) and
   [`cl-process-kit`](https://github.com/nerima-lisp/cl-process-kit) had each
   independently hand-rolled "decode as much of a byte buffer as forms
   complete characters, and hand back the incomplete trailing sequence" for
   UTF-8 alone. [`decode-prefix`](reference/api.md) generalizes that across
   every encoding this library implements.
2. **A from-scratch implementation, deliberately.** This library does not
   delegate to `sb-ext`'s external-format machinery in its shipped system.

See the [roadmap](project/roadmap.md) for what is and is not implemented yet.
