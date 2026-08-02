;;;; t/utf-16-test.lisp
(in-package #:cl-codec-kit/test)

(describe
  "UTF-16"
  (it "round-trips BMP and supplementary-plane text through BE and LE"
    (dolist (encoding '(:utf-16be :utf-16le))
      (dolist (s (list "" "hello" "日本語" "😀" "a😀b"))
        (expect (octets-to-string (string-to-octets s :encoding encoding) :encoding encoding)
                :to-equal s))))

  (it-property "round-trips any BMP+supplementary string through BE, for any length"
      ((values (gen-scalar-string :max #x10FFFF :min-length 0 :max-length 24)))
    (expect (octets-to-string (string-to-octets values :encoding :utf-16be) :encoding :utf-16be)
            :to-equal values))

  (it "encodes a supplementary-plane character as a surrogate pair, big-endian"
    ;; :TO-EQUALP, not :TO-EQUAL: CL:EQUAL falls through to EQ on octet
    ;; vectors and would pass regardless of content.
    (expect (string-to-octets (string (code-char #x10348)) :encoding :utf-16be)
            :to-equalp (octets #xD8 #x00 #xDF #x48)))

  (it "senses a byte-order mark for generic :UTF-16 and strips it"
    (expect (octets-to-string (octets #xFE #xFF #x00 #x41) :encoding :utf-16) :to-equal "A")
    (expect (octets-to-string (octets #xFF #xFE #x41 #x00) :encoding :utf-16) :to-equal "A")
    (expect (octets-to-string (octets #x00 #x41) :encoding :utf-16) :to-equal "A"))

  (it "signals SURROGATE-CODE-POINT on a lone low surrogate"
    (signals surrogate-code-point (octets-to-string (octets #xDC #x00) :encoding :utf-16be)))

  (it "signals SURROGATE-CODE-POINT on a high surrogate not followed by a low surrogate"
    (signals surrogate-code-point
        (octets-to-string (octets #xD8 #x00 #x00 #x41) :encoding :utf-16be)))

  (it "signals TRUNCATED-SEQUENCE on a dangling unit or half a surrogate pair"
    (signals truncated-sequence (octets-to-string (octets #x00) :encoding :utf-16be))
    (signals truncated-sequence (octets-to-string (octets #xD8 #x00) :encoding :utf-16be)))

  (it "signals UNENCODABLE-CHARACTER naming the exact BE/LE encoding requested"
    (handler-case
        (progn (string-to-octets (string (code-char #xDC00)) :encoding :utf-16be)
               (error "expected UNENCODABLE-CHARACTER"))
      (unencodable-character (c) (expect (unencodable-character-encoding c) :to-be :utf-16be)))
    (handler-case
        (progn (string-to-octets (string (code-char #xDC00)) :encoding :utf-16le)
               (error "expected UNENCODABLE-CHARACTER"))
      (unencodable-character (c) (expect (unencodable-character-encoding c) :to-be :utf-16le))))

  (it ":ERRORP NIL resyncs by whole code units, not by one octet"
    ;; A truncated surrogate pair yields exactly one replacement, not one per
    ;; leftover octet -- advancing by the wrong stride here would decode
    ;; #x0000 as a spurious extra character. This is the scenario that made
    ;; :RESYNC-WIDTH necessary on CHARACTER-ENCODING (registry.lisp).
    (let ((result (octets-to-string (octets #x00 #x41 #xD8 #x00) :encoding :utf-16be :errorp nil)))
      (expect (length result) :to-be 2)
      (expect (char result 0) :to-be #\A)
      (expect (char result 1) :to-be #\REPLACEMENT_CHARACTER))))
