;;; website csv.lisp - Andrew Stine (C) 2009-2010

(in-package #:sacraspot)

;;; Some functions for parsing csv text

(defun parse-csv-stream (csv-stream)
  "parses a csv stream into a list of lists, each sublist
   corresponding to a row in the csv stream"
  (declare (type stream csv-stream))
  (let ((out-rows nil)
	(row nil)
	(cell (make-string-output-stream))
	(in-quotes nil)
	(escaped nil))
    (labels ((push-char (char)
	       (write-char char cell))
	     (push-cell ()
	       (push (get-output-stream-string cell) row))
	     (push-row ()
	       (push-cell)
	       (push (nreverse row) out-rows)
	       (setf row nil)))
      (awhile (read-char csv-stream nil)
	(cond (escaped (push-char it)
		       (setf escaped nil))
	      ((char= it #\") (setf in-quotes (not in-quotes)))
	      ((char= it #\\) (setf escaped t))
	      (in-quotes (push-char it))
	      ((char= it #\newline) (push-row))
	      ((char= it #\,) (push-cell))
	      (t (push-char it))))
      (push-row)
      (nreverse out-rows))))
  
(defun parse-csv (csv)
  "like 'parse-csv-stream' but accepts a string as input"
  (typecase csv
    (string (parse-csv-stream (make-string-input-stream csv)))
    (stream (parse-csv-stream csv))
    (null (error "Null CSV"))
    (t (error "Bad CSV: ~a, wrong type: ~a" csv (type-of csv)))))
