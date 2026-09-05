(defpackage #:cl-codec-kit
  (:use #:cl)
  (:export
   #:octets-to-string
   #:string-to-octets
   #:string-size-in-octets
   #:decode-prefix
   #:lenient-decode-prefix
   #:*default-encoding*
   #:list-character-encodings
   #:find-character-encoding
   #:character-encoding-default-replacement

   #:cl-codec-kit-error
   #:decode-error
   #:decode-error-position
   #:unsupported-encoding
   #:unsupported-encoding-designator
   #:streaming-unsafe-encoding
   #:streaming-unsafe-encoding-designator
   #:invalid-leading-byte
   #:invalid-leading-byte-position
   #:invalid-leading-byte-octet
   #:invalid-continuation-byte
   #:invalid-continuation-byte-position
   #:invalid-continuation-byte-octet
   #:overlong-sequence
   #:overlong-sequence-position
   #:surrogate-code-point
   #:surrogate-code-point-position
   #:surrogate-code-point-value
   #:code-point-too-large
   #:code-point-too-large-position
   #:code-point-too-large-value
   #:truncated-sequence
   #:truncated-sequence-position
   #:unencodable-character
   #:unencodable-character-char
   #:unencodable-character-encoding
   #:unencodable-character-position))

(in-package #:cl-codec-kit)
