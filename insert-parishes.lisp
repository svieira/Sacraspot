;;; website insert-parishes.lisp - Andrew Stine (C) 2009-2010

(in-package #:sacraspot)

;;; This allows for client applications to add parishes directly to the server
;;; Post requests are directed at /insert-parishes with a single parameter:
;;; parishes. Parishes should contain a string containing parish information
;;; arranged in CSV format. Each row of the CSV should be a separate parish
;;; with the fields represented as such:
;;; "fullname","shortname","country","state","city","street","street-number","zip","phone","email","website","latitude","longitude","diocese"

(defun insert-parish (fullname shortname country state city street street-number 
		      zip phone email website latitude longitude diocese)
  "Adds a parish entry with the provided fields into the 'parishes' table."
  (let ((clean-phone (clean-phone phone)))
					;validate info
    (unless (or (null email)
		(equal "" email)
		(scan "[a-zA-Z0-9_.-]+@[a-zA-Z0-9_.-]+[.].+" email))
      (error "Bad email address being added to parish table"))
    (unless (or (null clean-phone)
		(equal "" clean-phone)
		(= (length clean-phone) 10))
      (error "Bad phone number being added to parish table"))
    (execute (:insert-into 'parishes :set
			   'fullname fullname
			   'shortname shortname
			   'country country
			   'state state
			   'city city
			   'street street
			   'street_number (if (equal street-number "") "0" street-number)
			   'zip zip
			   'phone clean-phone
			   'email email
			   'website website
			   'latitude latitude
			   'longitude longitude
			   'diocese diocese))))

(define-easy-handler (insert-parishes :uri "/insert-parishes" :default-request-type :post) ()
  "Handles calls to insert-parishes; parses CSV and insert-parishes for each row"
  (with-connection *connection-spec*
    ;(write-to-string (length (delete '("") (fetch-parameter "parishes" nil #'parse-csv) :test #'equal)))))
    (dolist (parish (delete '("") (fetch-parameter "parishes" nil #'parse-csv) :test #'equal))
      (apply #'insert-parish parish)))
  "worked")
