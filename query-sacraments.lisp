;;; website query-sacraments.lisp - Andrew Stine (C) 2009-2010

(in-package #:sacraspot)

;;query elements:
;ip         - ip used for geolocation, defaults to requestors ip
;time       - timestamp for searching on, defaults to 'now'
;latitude   - geolocation, defaults to what is derived from ip
;longitude  - geolocation, defaults to what is derived from ip
;distance   - in miles, search scope, defaults to 25
;future     - search scope, in seconds, defaults to 5 days (432,000 seconds)
;maxresults - maximum number of results returned, defaults to 25
;sacraments - json list of sacraments to search for, defaults to mass and confession

(defun generate-sacraments-query (parish-id time distance future maxresults sacraments language latitude longitude)
  "Returns the query used to pull lists of upcoming local sacraments"
  (declare (type local-time:timestamp time) (type integer distance future maxresults)
	   (type (or null string) language) (type list sacraments) (type float latitude longitude))
  (sql (:limit
	(:order-by
	 (:select 'events.parish_id 'events.schedule_id 'fullname 'city 'state 'sacrament_type 'time 'details 'language 'latitude 'longitude
		  (:as (:ll_distance 'latitude latitude 
				     'longitude longitude) 
		       'distance)
		  (:as (:+ (:* (:ll_distance 'latitude latitude
					     'longitude longitude)
			       6)
			   (:/ (:extract 'epoch (:- 'time time)) 360) )
		       'weight)
		  :from 'events
		  :inner-join 'parishes :on (:= 'events.parish_id 
						'parishes.parish_id)
		  :inner-join 'schedules :on (:= 'events.schedule_id 
						 'schedules.schedule_id)
		  :where (:and (:< (:ll_distance 'latitude latitude 
						 'longitude longitude) 
				   distance)
			       (:raw (sql-compile
				      `(:or
					,@(mapcar (lambda (sacrament)
						    `(:= 'sacrament_type ,sacrament))
						  sacraments))))
			       (:raw (sql-compile (if language `(:= 'language ,language) t)))
			       (:raw (sql-compile (if parish-id `(:= 'events.parish_id ,parish-id) t)))
			       (:> 'time time)
			       (:< 'time (timestamp+ time future :sec))))
	 'weight)
	maxresults)))

(defun query-sacraments (parish-id time distance future maxresults sacraments language latitude longitude)
  "Returns a JSON string containing the results of query based on the constraints provided."
  (declare (type local-time:timestamp time) (type integer distance future maxresults)
	   (type (or null string) language) (type list sacraments) (type float latitude longitude))
  (yason:with-output-to-string* ()
    (yason:with-array ()
      (doquery (:raw (generate-sacraments-query parish-id time distance future maxresults sacraments language latitude longitude))
	  (parish-id schedule-id fullname city state kind time details language latitude longitude distance weight)
	(yason:with-object ()
	  (yason:encode-object-element "PARISH_ID" parish-id)
	  (yason:encode-object-element "SCHEDULE_ID" schedule-id)
	  (yason:encode-object-element "FULLNAME" fullname)
	  (yason:encode-object-element "CITY" city)
	  (yason:encode-object-element "STATE" state)
	  (yason:encode-object-element "KIND" kind)
	  (yason:encode-object-element "TIME" (format-hr-timestamp time))
	  (yason:encode-object-element "DETAILS" details)
	  (yason:encode-object-element "LANGUAGE" language)
	  (yason:encode-object-element "LATITUDE" latitude)
	  (yason:encode-object-element "LONGITUDE" longitude)
	  (yason:encode-object-element "DISTANCE" distance)
	  (yason:encode-object-element "WEIGHT"  weight))))))

(defun query-sacraments-html (parish-id time distance future maxresults sacraments language latitude longitude)
  "Returns a HTML string containing the results of query based on the constraints provided."
  (declare (type local-time:timestamp time) (type integer distance future maxresults)
	   (type (or null string) language) (type list sacraments) (type float latitude longitude))
  (with-html-output-to-string (*standard-output*)
    (:table :id "sacraments" :class "sacraments-table"
      (doquery (:raw (generate-sacraments-query parish-id time distance future maxresults sacraments language latitude longitude))
	  (parish-id schedule-id fullname city state kind time details language latitude longitude distance weight)
	(htm (:tr
	       (:td (str kind))
	       (:td (str fullname))
	       (:td (str (format nil "~A, ~A" city state)))
	       (:td (str (format-hr-timestamp time)))
	       (:td (str details))
	       (:td (str (format nil "~R miles" (round distance))))))))))

(defmacro with-sacraments-query-parameters (&body body)
  "When run within a http callback, fetches and binds the parameters that are expected of
   a call to query-sacraments"
    `(handler-bind ((bad-input-error (lambda (c)
				       (unless *debug*
					 (invoke-restart 'use-default)))))
       (let ((parish-id (fetch-parameter "parish_id" :typespec '(or integer null)))
	     (time (fetch-parameter "time" :default (now) :parser #'parse-timestring :typespec 'local-time:timestamp))
	     (distance (fetch-parameter "distance" :default 25 :typespec 'integer))
	     (future (fetch-parameter "future" :default 453000 :typespec 'integer))
	     (maxresults (fetch-parameter "maxresults" :default 25 :typespec 'integer))
	     (sacraments (fetch-parameter "sacraments" :default '("Mass" "Confession") :parser #'yason:parse :typespec '(or list null)))
	     (language (fetch-parameter "language")))
	 (with-location
	     ,@body))))

(define-easy-handler (query-sacraments* :uri "/query-sacraments" :default-request-type :post) ()
  "Handles calls to query-sacraments"
  (with-connection *connection-spec*
    (with-sacraments-query-parameters
      (query-sacraments parish-id time distance future maxresults sacraments language latitude longitude))))

(define-easy-handler (query-sacraments-html* :uri "/query-sacraments-html" :default-request-type :post) ()
  "Handles calls to query-sacraments-html"
  (with-connection *connection-spec*
    (with-sacraments-query-parameters
      (let ((*string-modifier* #'identity))
	(with-output-to-string (*standard-output*)
	  (fill-and-print-template (pathname "/var/www/localhost/htdocs/www/fallback-frontpage.html")
				   `(:sacraments ,(query-sacraments-html parish-id time distance future maxresults sacraments language latitude longitude))
				   :stream *standard-output*))))))
