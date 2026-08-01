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
  ;; The default replacement is #x1A (SUB); this compares CHAR-CODE rather
  ;; than embedding the raw control character in a literal, so a failing
  ;; expectation's printed diff never contains it. UTF-16's own lenient-mode
  ;; resync behavior (RESYNC-WIDTH) is covered in utf-16-test.lisp instead of
  ;; duplicated here.
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
    (expect (octets-to-string (octets #xFE #xFF #x00 #x41) :encoding :utf-16) :to-equal "A")))

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
                                      (string-to-octets (string (code-char #x1a))
                                                        :encoding :utf-16be)
                                      (string-to-octets "b" :encoding :utf-16be)))))

  (it "propagates UNENCODABLE-CHARACTER rather than looping when REPLACEMENT itself cannot encode"
    (signals unencodable-character
        (string-to-octets (format nil "A~CB" (code-char 200))
                          :encoding :ascii :errorp nil :replacement (code-char 200)))))
