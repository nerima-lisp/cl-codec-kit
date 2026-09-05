(in-package #:cl-codec-kit/test)

(describe
  "the surrogate-range boundary check every codec here shares"
  (it "kills every mutation of the boundary comparison with a perfect score"
    (let ((results
            (run-mutations
             '(and (not (<= #xD800 0))            ; codespace minimum
                   (not (<= #xD800 #xD7FF))        ; one below the range
                   (<= #xD800 #xD800 #xDFFF)       ; range minimum
                   (<= #xD800 #xDBFF #xDFFF)       ; last high surrogate
                   (<= #xD800 #xDC00 #xDFFF)       ; first low surrogate
                   (<= #xD800 #xDFFF #xDFFF)       ; range maximum
                   (not (<= #xE000 #xDFFF))        ; one above the range
                   (not (<= #x10FFFF #xDFFF)))     ; codespace maximum
             (lambda (form mutation)
               (declare (ignore mutation))
               (eq (eval form) t)))))
      (assert-mutation-score results 1.0))))
