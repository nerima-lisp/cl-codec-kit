;;;; t/api-test.lisp
(in-package #:cl-codec-kit/test)

(describe
  "STRING-SIZE-IN-OCTETS"
  (it "matches the length STRING-TO-OCTETS actually produces"
    (dolist (s (list "" "hello" "café" "日本語" "😀"))
      (dolist (encoding '(:utf-8 :utf-16be :utf-32be :ascii))
        (when (or (not (eq encoding :ascii)) (every (lambda (c) (< (char-code c) #x80)) s))
          (expect (string-size-in-octets s :encoding encoding)
                  :to-be (length (string-to-octets s :encoding encoding)))))))

  (it "honors :START and :END the same way STRING-TO-OCTETS does"
    (expect (string-size-in-octets "xcaféy" :start 1 :end 5 :encoding :utf-8)
            :to-be (length (string-to-octets "café" :encoding :utf-8)))))

(describe
  "OCTETS-TO-STRING lenient mode across encodings"
  ;; ASCII's default replacement is #x1A (SUB); this compares CHAR-CODE
  ;; rather than embedding the raw control character in a literal, so a
  ;; failing expectation's printed diff never contains it. UTF-16's own
  ;; lenient-mode resync behavior (RESYNC-WIDTH) is covered in
  ;; utf-16-test.lisp instead of duplicated here.
  (it "replaces an invalid ASCII byte and keeps going, one octet at a time"
    (let ((result (octets-to-string (octets #x41 #xFF #x42) :encoding :ascii :errorp nil)))
      (expect (length result) :to-be 3)
      (expect (char result 0) :to-be #\A)
      (expect (char-code (char result 1)) :to-be #x1a)
      (expect (char result 2) :to-be #\B)))

  (it ":ERRORP NIL signals STREAMING-UNSAFE-ENCODING for the generic designators"
    (dolist (encoding '(:utf-16 :utf-32 :ucs-2))
      (signals streaming-unsafe-encoding
          (octets-to-string (octets #x00) :encoding encoding :errorp nil))))

  (it ":ERRORP T (the default) still decodes a generic designator in one shot"
    (expect (octets-to-string (octets #xFE #xFF #x00 #x41) :encoding :utf-16) :to-equal "A"))

  (it "replaces a sequence truncated at the true end with exactly one REPLACEMENT"
    ;; #xE3 #x81 is two of the three bytes UTF-8 needs for a character -- one
    ;; malformed attempt, not two. A resync-width-based resume would land back
    ;; inside the same truncated fragment (#x81 alone is not a valid leading
    ;; byte either) and emit a second, spurious REPLACEMENT for it.
    (let ((result (octets-to-string (octets #xE3 #x81) :encoding :utf-8 :errorp nil)))
      (expect (length result) :to-be 1)
      (expect (char result 0) :to-be #\REPLACEMENT_CHARACTER))))

(describe
  "STRING-TO-OCTETS strict mode reports POSITION"
  (it "names the string index of the first unencodable character, not just the character"
    (handler-case (progn (string-to-octets (format nil "ab~Ccd" (code-char 200)) :encoding :ascii)
                         (error "expected UNENCODABLE-CHARACTER"))
      (unencodable-character (c)
        (expect (unencodable-character-position c) :to-be 2)
        (expect (unencodable-character-char c) :to-be (code-char 200))))))

(describe
  "STRING-TO-OCTETS lenient mode across encodings"
  (it "replaces an unencodable ASCII character and keeps going, one character at a time"
    (let ((result (string-to-octets (format nil "A~CB" (code-char 200))
                                    :encoding :ascii :errorp nil)))
      (expect result :to-equalp (octets #x41 #x1a #x42))))

  (it "honors a custom :REPLACEMENT character"
    (let ((result (string-to-octets (format nil "A~CB" (code-char 200))
                                    :encoding :ascii :errorp nil :replacement #\?)))
      (expect result :to-equalp (octets #x41 #x3f #x42))))

  (it "resumes by one string index (never a resync width) after a lone UTF-16BE surrogate"
    (let* ((lone-surrogate (code-char #xD800))
           (result (string-to-octets (format nil "a~Cb" lone-surrogate)
                                     :encoding :utf-16be :errorp nil)))
      (expect result
              :to-equalp (concatenate '(vector (unsigned-byte 8))
                                      (string-to-octets "a" :encoding :utf-16be)
                                      (string-to-octets (string #\REPLACEMENT_CHARACTER)
                                                        :encoding :utf-16be)
                                      (string-to-octets "b" :encoding :utf-16be)))))

  (it "propagates UNENCODABLE-CHARACTER rather than looping when REPLACEMENT itself cannot encode"
    (signals unencodable-character
        (string-to-octets (format nil "A~CB" (code-char 200))
                          :encoding :ascii :errorp nil :replacement (code-char 200)))))

(describe
  "the omitted :REPLACEMENT resolves per encoding, in both directions"
  ;; registry-test.lisp pins the table itself and cites the babel source it
  ;; was transcribed from. These tests pin that the table is what the three
  ;; lenient entry points actually reach for -- the regression that matters
  ;; is a library-wide constant creeping back into any one of them, which the
  ;; table test alone would not catch.
  (it "substitutes U+FFFD when decoding under any Unicode-family encoding"
    (dolist (case '((:utf-8    (#x41 #x80 #x42))
                    (:utf-16be (#x00 #x41 #xDC #x00 #x00 #x42))
                    (:utf-16le (#x41 #x00 #x00 #xDC #x42 #x00))
                    (:utf-32be (#x00 #x00 #x00 #x41 #x00 #x11 #x00 #x00 #x00 #x00 #x00 #x42))
                    (:utf-32le (#x41 #x00 #x00 #x00 #x00 #x00 #x11 #x00 #x42 #x00 #x00 #x00))
                    (:ucs-2be  (#x00 #x41 #xD8 #x00 #x00 #x42))
                    (:ucs-2le  (#x41 #x00 #x00 #xD8 #x42 #x00))))
      (destructuring-bind (encoding bytes) case
        (expect (octets-to-string (apply #'octets bytes) :encoding encoding :errorp nil)
                :to-equal (format nil "A~CB" #\REPLACEMENT_CHARACTER)))))

  (it "substitutes #x1A (SUB) when decoding under :ASCII, the same call shape"
    ;; :ISO-8859-1 has no decode-side counterpart: every octet value is a
    ;; valid Latin-1 character, so its decoder can never substitute anything.
    (expect (octets-to-string (octets #x41 #xFF #x42) :encoding :ascii :errorp nil)
            :to-equal (format nil "A~CB" (code-char #x1a))))

  (it "substitutes each encoding's own default when encoding, too"
    ;; Asserted against a strict encode of the expected replacement rather
    ;; than a literal octet list, so the expectation stays readable and does
    ;; not restate each encoding's byte layout.
    ;;
    ;; The three generic, BOM-sensing designators are excluded: their
    ;; encoders emit a byte-order mark per call, and %LENIENT-ENCODE calls an
    ;; encoder once per chunk, so their :ERRORP NIL output carries a BOM
    ;; before every chunk. That is a separate defect and asserting on it here
    ;; would pin it as intended behavior.
    (dolist (case (list (list :utf-8      (code-char #xD800) #\REPLACEMENT_CHARACTER)
                        (list :utf-16be   (code-char #xD800) #\REPLACEMENT_CHARACTER)
                        (list :utf-16le   (code-char #xD800) #\REPLACEMENT_CHARACTER)
                        (list :utf-32be   (code-char #xD800) #\REPLACEMENT_CHARACTER)
                        (list :utf-32le   (code-char #xD800) #\REPLACEMENT_CHARACTER)
                        (list :ucs-2be    (code-char #x10000) #\REPLACEMENT_CHARACTER)
                        (list :ucs-2le    (code-char #x10000) #\REPLACEMENT_CHARACTER)
                        (list :ascii      (code-char #xC8) (code-char #x1a))
                        (list :iso-8859-1 (code-char #x100) (code-char #x1a))))
      (destructuring-bind (encoding unencodable expected) case
        (expect (string-to-octets (format nil "a~Cb" unencodable)
                                  :encoding encoding :errorp nil)
                :to-equalp (string-to-octets (format nil "a~Cb" expected)
                                             :encoding encoding)))))

  (it "still honors an explicit :REPLACEMENT, which overrides the encoding's default"
    (expect (octets-to-string (octets #x41 #x80 #x42) :encoding :utf-8 :errorp nil
                              :replacement #\?)
            :to-equal "A?B")
    (expect (string-to-octets (format nil "a~Cb" (code-char #xD800))
                              :encoding :utf-8 :errorp nil :replacement #\?)
            :to-equalp (string-to-octets "a?b" :encoding :utf-8))))
