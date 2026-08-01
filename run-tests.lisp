;;;; run-tests.lisp
;;;;
;;;; Bootstrap script: register this checkout's and cl-weave's ASDF
;;;; definitions and run the test system without scanning every inherited
;;;; source registry tree.

(require :asdf)
(format t "tests: bootstrap~%")

(defun script-directory ()
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                               *compile-file-truename*
                               (error "Unable to determine the script location"))))

(let ((root (script-directory)))
  (format t "tests: system definition~%")
  (push root asdf:*central-registry*)
  (push (merge-pathnames #P"../cl-weave/" root) asdf:*central-registry*)
  (format t "tests: run~%")
  (asdf:test-system "cl-codec-kit")
  (format t "tests: complete~%")
  (uiop:quit 0))
