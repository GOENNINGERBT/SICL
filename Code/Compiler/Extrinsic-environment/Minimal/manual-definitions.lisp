(cl:in-package #:sicl-minimal-extrinsic-environment)

;;; The SICL reader defines macros that are generated by the backquote
;;; facility.  These macros must exist in the SICL global environment
;;; so that they can be expanded by the compiler.

(defun define-setf-symbol-value (environment)
  (setf (sicl-genv:fdefinition '(setf symbol-value) environment) 
        #'(setf symbol-value)))

(defun define-symbol-value (environment)
  (setf (sicl-genv:fdefinition 'symbol-value environment) #'symbol-value))

(defun define-find-package (environment)
  (setf (sicl-genv:fdefinition 'find-package environment)
        (lambda (name) (sicl-genv:find-package name environment))))

;;; Eclector defines macros that are generated by the backquote
;;; facility.  These macros must exist in the SICL global environment
;;; so that they can be expanded by the compiler.

(defun define-backquote-macros (environment)
  (setf (sicl-genv:fdefinition 'eclector.reader::expand environment)
	(fdefinition 'eclector.reader::transform))
  (setf (sicl-genv:macro-function 'eclector.reader::quasiquote environment)
	(macro-function 'eclector.reader::quasiquote)))

;;; We need to start using DEFMACRO early on to define macros, and
;;; since we don't already have it, we must create it "manually".
;;; This version is incorrect, though, because it uses the host
;;; compiler both to create the macro function for DEFMACRO (which is
;;; fine) and for creating the macro function for the macros defined
;;; by DEFMACRO (which is not fine).  As a result, the macros defined
;;; by this version of DEFMACRO must be defined in the NULL lexical
;;; environment.  Luckily, most macros are, and certainly the ones we
;;; need to define with this version of DEFMACRO until we can replace
;;; it with a native version.
(defun define-defmacro (environment)
  (setf (sicl-genv:macro-function 'defmacro environment)
	(compile nil
		 (cleavir-code-utilities:parse-macro
		  'defmacro
		  '(name lambda-list &body body)
		  `((eval-when (:compile-toplevel :load-toplevel :execute)
		      (setf (sicl-genv:macro-function name ,environment)
			    (compile nil
				     (cleavir-code-utilities:parse-macro
				      name
				      lambda-list
				      body)))))))))

;;;; This definition of IN-PACKAGE looks a bit strange.  The reason is
;;;; that when files are read by Eclector in order to be loaded, the
;;;; reader is executing in the host environment.  When an IN-PACKAGE
;;;; form is encountered, the host *PACKAGE* variable must be updated
;;;; so that subsequent forms are read in the right package.  But we
;;;; also want the variable *PACKAGE* in the extrinsic environment to
;;;; be updated.

(defun define-in-package (environment)
  (setf (sicl-genv:macro-function 'in-package environment)
	(lambda (form environment)
	  (declare (ignore environment))
	  (setq *package* (find-package (cadr form)))
	  `(setq *package* (find-package ',(cadr form))))))

(defun define-default-setf-expander (environment)
  (setf (sicl-genv:default-setf-expander environment)
	(lambda (form environment)
          (declare (ignore environment))
	  (if (symbolp form)
	      (let ((new (gensym)))
		(values '()
			'()
			`(,new)
			`(setq ,form ,new)
			form))
	      (let ((temps (loop for arg in (rest form) collect (gensym)))
		    (new (gensym)))
		(values temps
			(rest form)
			`(,new)
			`(funcall #'(setf ,(first form)) ,new ,@temps)
			`(,(first form) ,@temps)))))))

(defun define-setf-macro-function (environment)
  (setf (sicl-genv:fdefinition '(setf sicl-genv:macro-function) environment)
        #'(setf sicl-genv:macro-function)))

(defun define-global-environment (environment)
  (setf (sicl-genv:special-variable 'sicl-genv:*global-environment*  environment t)
        environment))
