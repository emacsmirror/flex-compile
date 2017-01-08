;;; compile-flex-xml-validate.el --- xml validation

;; Copyright (C) 2015 - 2017 Paul Landes

;; Author: Paul Landes
;; Maintainer: Paul Landes
;; Keywords: xml validation compilation

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; Implementation compiler for XML validation using command line `xmllint'

;;; Code:

(require 'compile-flex)
(eval-when-compile (require 'xml))

(defclass xml-validate-flex-compiler (run-args-flex-compiler)
  ((buffer-name :initarg :buffer-name
		:initform "*XML Validation*"
		:type string)
   (xmllint-program :initarg :xmllint-program
		    :initform "xmllint")
   (schema-file :initarg :schema-file
		:initform nil
		:documentation "\
Location of the schema file to validate against.")))

(defmethod initialize-instance ((this xml-validate-flex-compiler) &rest rest)
  (oset this :name "xml-validate")
  (oset this :config-file-desc "XML instance file")
  (oset this :major-mode 'nxml-mode)
  (oset this :mode-desc "xml-validate")
  (apply 'call-next-method this rest))

(defmethod flex-compiler-load-libraries ((this xml-validate-flex-compiler))
  (require 'xml))

(defmethod flex-compiler-guess-schema-file ((this xml-validate-flex-compiler))
  "Try to determine where the XSD is by the location "
  (with-temp-buffer
    (->> (flex-compiler-config this)
	 insert-file-contents)
    (condition-case nil
	(->> (xml-parse-region (point-min) (point-max))
	     car
	     xml-node-attributes
	     (assq 'xsi:schemaLocation)
	     cdr
	     (funcall #'(lambda (xsi)
			  (if (string-match "file://\\(.*\\)$" xsi)
			      (match-string 1 xsi)))))
      (error))))

(defmethod flex-compiler-read-options ((this xml-validate-flex-compiler))
  (let* ((schema-guess (flex-compiler-guess-schema-file this))
	 (initial (and schema-guess (file-name-nondirectory schema-guess)))
	 (dir (and schema-guess (file-name-directory schema-guess)))
	 (schema (read-file-name "Schema XSD: " dir schema-guess t initial)))
    (and schema (oset this :schema-file schema))
    nil))

(defmethod flex-compiler-xml-validate-schema ((this xml-validate-flex-compiler))
  (with-slots (schema-file) this
    (if (not schema-file)
	(error "No schema file set"))
    schema-file))

(defmethod flex-compiler-config-persist ((this xml-validate-flex-compiler))
  (append `((schema-file . ,(oref this :schema-file)))
	  (call-next-method this)))

(defmethod flex-compiler-config-unpersist ((this xml-validate-flex-compiler) config)
  (oset this :schema-file (cdr (assq 'schema-file config)))
  (call-next-method this config))

(defmethod flex-compiler-run-with-args ((this xml-validate-flex-compiler) args)
  (with-slots (buffer-name xmllint-program) this
    (let* ((config-file (flex-compiler-config this))
	   (schema (flex-compiler-xml-validate-schema this))
	   (cmd (mapconcat #'identity
			   `(,xmllint-program "--noout" "--schema"
					      ,schema ,config-file)
			   " ")))
      (with-current-buffer
	  (compilation-start cmd nil
			     #'(lambda (mode-name)
				 buffer-name))
	(pop-to-buffer (current-buffer))))))

(flex-compile-manager-register the-flex-compile-manager
			       (xml-validate-flex-compiler nil))

(provide 'compile-flex-xml-validate)

;;; compile-flex-xml-validate.el ends here
