(cl:in-package #:sicl-new-boot-phase-3)

(defmethod sicl-genv:typep
    (object (type-specifier (eql 'function)) (environment environment))
  (typep object 'function))

;;; We only check for the type CLASS for reasons of catching errors,
;;; but during bootstrapping, we completely control the arguments, so
;;; we can simply return true here.
(defmethod sicl-genv:typep
    (object (type-specifier (eql 'class)) (environment environment))
  t)

;;; This function defines functions ADD-READER-METHOD and
;;; ADD-WRITER-METHOD in E3 that look up their generic functions in
;;; E4.  They do not call ADD-METHOD, because ADD-METHOD is defined to
;;; add methods to generic functions in E3.  The other defect these
;;; functions have is that they do not set the specializer profile on
;;; the generic function, so we have to do that manually in phase 4.
(defun define-add-accessor-method (e2 e3 e4)
  (setf (sicl-genv:fdefinition 'sicl-clos::add-reader-method e3)
        (lambda (class function-name slot-definition)
          (let* ((lambda-list '(object))
                 (generic-function (sicl-genv:fdefinition function-name e4))
                 (specializers (list class))
                 (slot-name (slot-value slot-definition 'sicl-clos::%name))
                 (method-function
                   (compile nil `(lambda (arguments next-methods)
                                   (declare (ignore next-methods))
                                   (slot-value (car arguments) ',slot-name))))
                 (method-class (sicl-genv:find-class
                                'sicl-clos:standard-reader-method e2))
                 (method (make-instance method-class
                           :lambda-list lambda-list
                           :qualifiers '()
                           :specializers specializers
                           :function method-function
                           :slot-definition slot-definition)))
            (push method (slot-value generic-function 'sicl-clos::%methods)))))
  (setf (sicl-genv:fdefinition 'sicl-clos::add-writer-method e3)
        (lambda (class function-name slot-definition)
          (let* ((lambda-list '(object))
                 (generic-function (sicl-genv:fdefinition function-name e4))
                 (specializers (list (sicl-genv:find-class 't e3) class))
                 (slot-name (slot-value slot-definition 'sicl-clos::%name))
                 (method-function
                   (compile nil `(lambda (arguments next-methods)
                                   (declare (ignore next-methods))
                                   (setf (slot-value (cadr arguments) ',slot-name)
                                         (car arguments)))))
                 (method-class (sicl-genv:find-class
                                'sicl-clos:standard-writer-method e2))
                 (method (make-instance method-class
                           :lambda-list lambda-list
                           :qualifiers '()
                           :specializers specializers
                           :function method-function
                           :slot-definition slot-definition)))
            (push method (slot-value generic-function 'sicl-clos::%methods))))))

(defun define-ensure-class (boot)
  (with-accessors ((e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3))
      boot
    (setf (sicl-genv:fdefinition 'sicl-clos:ensure-class e3)
          (lambda (name
                   &rest keys
                   &key
                     direct-default-initargs
                     direct-slots
                     direct-superclasses
                     (metaclass nil metaclass-p)
                   &allow-other-keys)
            (let* ((metaclass-name (if metaclass-p metaclass 'standard-class))
                   (metaclass-class (sicl-genv:find-class metaclass-name e2))
                   (superclasses (loop for name in direct-superclasses
                                       collect (sicl-genv:find-class name e2)))
                   (remaining-keys (copy-list keys)))
              (loop while (remf remaining-keys :metaclass))
              (loop while (remf remaining-keys :direct-superclasses))
              (setf (sicl-genv:find-class name e3)
                    (apply #'make-instance metaclass-class
                           :direct-default-initargs direct-default-initargs
                           :direct-slots direct-slots
                           :direct-superclasses superclasses
                           :name name
                           remaining-keys)))))))

(defun create-mop-classes (boot)
  (with-accessors ((e1 sicl-new-boot:e1)
                   (e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3)
                   (e4 sicl-new-boot:e4))
      boot
    (import-functions-from-host '(sicl-genv:typep) e3)
    (setf (sicl-genv:fdefinition 'sicl-clos:validate-superclass e3)
          (lambda (class direct-superclass)
            (declare (ignore class direct-superclass))
            t))
    (setf (sicl-genv:fdefinition 'sicl-clos:direct-slot-definition-class e3)
          (lambda (&rest arguments)
            (declare (ignore arguments))
            (sicl-genv:find-class 'sicl-clos:standard-direct-slot-definition e2)))
    (import-functions-from-host '(remove) e3)
    (load-file "CLOS/add-remove-direct-subclass-support.lisp" e3)
    (load-file "CLOS/add-remove-direct-subclass-defgenerics.lisp" e3)
    (load-file "CLOS/add-remove-direct-subclass-defmethods.lisp" e3)
    (define-add-accessor-method e2 e3 e4)
    (setf (sicl-genv:fdefinition 'sicl-clos:default-superclasses e3)
          (lambda (class) (declare (ignore class)) '()))
    (load-file "CLOS/class-initialization-support.lisp" e3)
    (load-file "CLOS/class-initialization-defmethods.lisp" e3)
    nil))
