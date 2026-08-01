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
  ;; The default replacement is #x1A (SUB); these compare CHAR-CODE rather
  ;; than embedding the raw control character in a literal, so a failing
  ;; expectation's printed diff never contains it.
  (it "replaces a truncated UTF-16 surrogate pair at the buffer's end"
    (let ((result (octets-to-string (octets #x00 #x41 #xD8 #x00) :encoding :utf-16be :errorp nil)))
      (expect (length result) :to-be 2)
      (expect (char result 0) :to-be #\A)
      (expect (char-code (char result 1)) :to-be #x1a)))
  (it "replaces an unencodable-by-decode ASCII byte and keeps going"
    (let ((result (octets-to-string (octets #x41 #xFF #x42) :encoding :ascii :errorp nil)))
      (expect (length result) :to-be 3)
      (expect (char result 0) :to-be #\A)
      (expect (char-code (char result 1)) :to-be #x1a)
      (expect (char result 2) :to-be #\B))))
