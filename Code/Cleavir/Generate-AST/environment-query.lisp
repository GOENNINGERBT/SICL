(cl:in-package #:cleavir-generate-ast)

(defun variable-info (environment symbol)
  (let ((result (cleavir-env:variable-info environment symbol)))
    (loop while (null result)
	  do (restart-case (error 'cleavir-env:no-variable-info
				  :name symbol)
	       (consider-special ()
		 :report (lambda (stream)
			   (format stream "Consider the variable as special."))
		 (return-from variable-info
		   (make-instance 'cleavir-env:special-variable-info
		     :name symbol)))
	       (substitute (new-symbol)
		 :report (lambda (stream)
			   (format stream "Substitute a different name."))
		 :interactive (lambda ()
				(format *query-io* "Enter new name: ")
				(list (read)))
		 (setq result (variable-info environment new-symbol)))))
    result))

(defun function-info (environment function-name)
  (let ((result (cleavir-env:function-info environment function-name)))
    (loop while (null result)
	  do (restart-case (error 'cleavir-env:no-function-info
				  :name function-name)
	       (consider-global ()
		 :report (lambda (stream)
			   (format stream
				   "Treat it as the name of a global function."))
		 (return-from function-info
		   (make-instance 'cleavir-env:global-function-info
		     :name function-name)))
	       (substitute (new-function-name)
		 :report (lambda (stream)
			   (format stream "Substitute a different name."))
		 :interactive (lambda ()
				(format *query-io* "Enter new name: ")
				(list (read)))
		 (setq result (function-info environment new-function-name)))))
    result))

