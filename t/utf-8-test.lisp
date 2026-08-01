;;;; t/utf-8-test.lisp
(in-package #:cl-codec-kit/test)

(describe
  "UTF-8"
  (it "round-trips ASCII, Latin, and multibyte text"
    (dolist (s (list "" "hello" "cafe" "café" "日本語" "αβγ" "😀" "a😀b日c"))
      (expect (octets-to-string (string-to-octets s :encoding :utf-8) :encoding :utf-8)
              :to-equal s)))

  (it-property "round-trips any string built from scalar values, for any length"
      ((values (gen-scalar-string :max #x10FFFF :min-length 0 :max-length 24)))
    (expect (octets-to-string (string-to-octets values :encoding :utf-8) :encoding :utf-8)
            :to-equal values))

  (it "encodes known code points to their documented UTF-8 byte sequences"
    (expect (string-to-octets (string (code-char #x24)) :encoding :utf-8) :to-equal (octets #x24))
    (expect (string-to-octets (string (code-char #xA2)) :encoding :utf-8)
            :to-equal (octets #xC2 #xA2))
    (expect (string-to-octets (string (code-char #x20AC)) :encoding :utf-8)
            :to-equal (octets #xE2 #x82 #xAC))
    (expect (string-to-octets (string (code-char #x10348)) :encoding :utf-8)
            :to-equal (octets #xF0 #x90 #x8D #x88)))

  (it "signals INVALID-LEADING-BYTE on a stray continuation or FE/FF byte"
    (signals invalid-leading-byte (octets-to-string (octets #x80) :encoding :utf-8))
    (signals invalid-leading-byte (octets-to-string (octets #xFF) :encoding :utf-8)))

  (it "signals INVALID-CONTINUATION-BYTE when a continuation byte is malformed"
    (signals invalid-continuation-byte (octets-to-string (octets #xE2 #x28 #xA1) :encoding :utf-8)))

  (it "signals INVALID-LEADING-BYTE for #xC0/#xC1, which the restricted grammar
excludes entirely since they could only ever start an overlong 2-byte sequence"
    (signals invalid-leading-byte (octets-to-string (octets #xC0 #x80) :encoding :utf-8))
    (signals invalid-leading-byte (octets-to-string (octets #xC1 #x80) :encoding :utf-8)))

  (it "signals OVERLONG-SEQUENCE for a non-minimal 3-byte encoding of U+0000"
    (signals overlong-sequence (octets-to-string (octets #xE0 #x80 #x80) :encoding :utf-8)))

  (it "signals SURROGATE-CODE-POINT for an encoded surrogate half"
    (signals surrogate-code-point (octets-to-string (octets #xED #xA0 #x80) :encoding :utf-8)))

  (it "signals CODE-POINT-TOO-LARGE above U+10FFFF"
    (signals code-point-too-large (octets-to-string (octets #xF4 #x90 #x80 #x80) :encoding :utf-8)))

  (it "signals TRUNCATED-SEQUENCE when a multibyte sequence runs off the end"
    (signals truncated-sequence (octets-to-string (octets #xE2 #x82) :encoding :utf-8))
    (signals truncated-sequence (octets-to-string (octets #xF0 #x90) :encoding :utf-8)))

  (it "honors :START and :END on both directions"
    (expect (octets-to-string (octets #x41 #xC3 #xA9 #x42) :start 1 :end 3 :encoding :utf-8)
            :to-equal "é")
    (expect (string-to-octets "xcafé y" :start 1 :end 5 :encoding :utf-8)
            :to-equal (string-to-octets "café" :encoding :utf-8)))

  (it "signals UNENCODABLE-CHARACTER for a raw surrogate half character"
    (signals unencodable-character
        (string-to-octets (string (code-char #xD800)) :encoding :utf-8)))

  (it ":ERRORP NIL replaces each bad byte and keeps decoding"
    ;; The default replacement is #x1A (SUB, a non-printing control
    ;; character); comparing its CHAR-CODE rather than embedding it in a
    ;; literal string keeps a failing expectation's printed diff free of a
    ;; raw control byte.
    (let ((result (octets-to-string (octets #x41 #x80 #x42) :encoding :utf-8 :errorp nil)))
      (expect (length result) :to-be 3)
      (expect (char result 0) :to-be #\A)
      (expect (char-code (char result 1)) :to-be #x1a)
      (expect (char result 2) :to-be #\B))
    (expect (octets-to-string (octets #x41 #x80 #x42) :encoding :utf-8 :errorp nil
                              :replacement #\?)
            :to-equal "A?B")))
