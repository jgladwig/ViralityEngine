(in-package :%first-light)

(defun qualify-component (core-state component-type)
  "This function tries to resolve the COMPONENT-TYPE symbol into a potentially
different packaged symbol of the same name that corresponds to a component
definition in that package. The packages are searched in the order they are are
defined in a toposort of the graph category COMPONENT-PACKAGE-ORDER. The result
should be a symbol suitable for MAKE-INSTANCE in all cases, but in the case of
mixin superclasses, it might not be desireable.

NOTE: If the component-type is a mixin class/component that is a superclass to a
component, then the first external to the package superclass definition found in
the package search order will be returned as the package qualified symbol.

NOTE: This function can not confirm that a symbol is a component defined by
DEFINE-COMPONENT. It can only confirm that the symbol passed to it is a
superclass of a DEFINE-COMPONENT form (up to but not including the COMPONENT
superclass type all components have), or a component created by the
DEFINE-COMPONENT form."
  (let ((search-table (component-search-table (tables core-state)))
        (component-type/class (find-class component-type nil))
        (base-component-type/class (find-class '%fl:component)))
    (fl.util:when-found (pkg-symbol (fl.util:href search-table component-type))
      (return-from qualify-component pkg-symbol))
    (if (or (null component-type/class)
            (not (subtypep (class-name component-type/class)
                           (class-name base-component-type/class))))
        (let ((graph (fl.util:href (analyzed-graphs core-state) 'component-package-order)))
          (dolist (potential-package (toposort graph))
            (let ((potential-package-name (second potential-package)))
              (dolist (pkg-to-search
                       (fl.util:href (pattern-matched-packages (annotation graph))
                                     potential-package-name))
                (multiple-value-bind (symbol kind)
                    (find-symbol (symbol-name component-type) pkg-to-search)
                  (when (and (eq kind :external)
                             (find-class symbol nil))
                    (setf (fl.util:href search-table component-type) symbol)
                    (return-from qualify-component symbol)))))))
        component-type)))

(defmethod make-component (component-type context &rest initargs)
  (let ((qualified-type (qualify-component (core-state context) component-type)))
    (apply #'make-instance qualified-type :type qualified-type :context context initargs)))

(defun %get-computed-component-precedence-list (component-type)
  ;; NOTE: We may very well be asking for classes that have not been finalized
  ;; because we haven't yet (or might not ever) call make-instance on them.
  ;; Hence we will compute right now the class precedence for it.
  ;; TODO: Fix this when FIND-CLASS returns NIL too.
  (loop :for class :in (c2mop:compute-class-precedence-list
                        (find-class component-type nil))
        :for name = (class-name class)
        :until (eq name 'component)
        :collect name))

(defun component/preinit->init (core-state component)
  (fl.util:when-let ((thunk (initializer-thunk component)))
    (funcall thunk)
    (setf (initializer-thunk component) nil))
  (let ((component-type (canonicalize-component-type (component-type component) core-state)))
    (with-slots (%tables) core-state
      (type-table-drop component component-type (component-preinit-by-type-view %tables))
      (setf (type-table component-type (component-init-by-type-view %tables)) component))))

(defun component/init->active (core-state component)
  (let ((component-type (canonicalize-component-type (component-type component) core-state)))
    (with-slots (%tables) core-state
      (type-table-drop component component-type (component-init-by-type-view %tables))
      (setf (state component) :active
            (type-table component-type (component-active-by-type-view %tables)) component))))

(defmethod destroy ((thing component) (context context) &key (ttl 0))
  (let ((core-state (core-state context)))
    (setf (ttl thing) (if (minusp ttl) 0 ttl)
          (fl.util:href (component-predestroy-view (tables core-state)) thing) thing)))

(defun component/init-or-active->destroy (core-state component)
  (let ((component-type (canonicalize-component-type (component-type component) core-state)))
    (with-slots (%tables) core-state
      (setf (state component) :destroy
            (type-table component-type (component-destroy-by-type-view %tables)) component)
      (remhash component (component-predestroy-view %tables))
      (unless (type-table-drop component component-type (component-active-by-type-view %tables))
        (type-table-drop component component-type (component-preinit-by-type-view %tables))))))

(defun component/destroy->released (core-state component)
  (let ((component-type (canonicalize-component-type (component-type component) core-state)))
    (type-table-drop component component-type (component-destroy-by-type-view (tables core-state)))
    (detach-component (actor component) component)))

(defun component/countdown-to-destruction (core-state component)
  (when (plusp (ttl component))
    (decf (ttl component) (frame-time (context core-state)))))

;;; User protocol

(defgeneric shared-storage-metadata (component-name &optional namespace)
  (:method ((component-name symbol) &optional namespace)
    (declare (ignore namespace))))

(defgeneric initialize-component (component)
  (:method ((component component))))

(defgeneric physics-update-component (component)
  (:method ((component component))))

(defgeneric update-component (component)
  (:method ((component component))))

(defgeneric render-component (component)
  (:method ((component component))))

(defgeneric destroy-component (component)
  (:method ((component component))))
