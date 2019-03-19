(in-package :%first-light)

(defvar *core-state-debug*)

(defclass core-state ()
  ((%resources :reader resources
               :initform (fl.data:get 'resources))
   (%options :accessor options)
   (%running-p :accessor running-p
               :initform t)
   (%rcache :reader rcache
            :initform (au:dict #'eq))
   (%frame-manager :accessor frame-manager
                   :initform nil)
   (%display :reader display
             :initform nil)
   (%scene-tree :reader scene-tree)
   (%cameras :accessor cameras
             :initform nil)
   (%input-data :reader input-data
                :initform (fl.input:make-input-data))
   (%shaders :accessor shaders)
   (%materials :accessor materials
               :initform (%make-materials-table))
   (%textures :accessor textures
              :initform (%make-textures-table))
   (%context :reader context)
   (%tables :reader tables
            :initform (make-instance 'bookkeeping-tables))
   (%call-flows :reader call-flows
                :initform (au:dict #'eq))
   (%analyzed-graphs :reader analyzed-graphs
                     :initform (au:dict #'equalp))
   (%scenes :reader scenes
            :initform (au:dict #'eq))
   (%recompilation-queue :reader recompilation-queue
                         :initarg :recompilation-queue
                         :initform (fl.dst:make-queue :simple-cqueue))))

(defclass bookkeeping-tables ()
  ((%component-search-table :reader component-search-table
                            :initform (au:dict #'eq))
   (%component-preinit-by-type-view :reader component-preinit-by-type-view
                                    :initform (au:dict #'eq))
   (%component-init-by-type-view :reader component-init-by-type-view
                                 :initform (au:dict #'eq))
   (%component-active-by-type-view :reader component-active-by-type-view
                                   :initform (au:dict #'eq))
   (%component-predestroy-view :reader component-predestroy-view
                               :initform (au:dict #'eq))
   (%component-destroy-by-type-view :reader component-destroy-by-type-view
                                    :initform (au:dict #'eq))
   (%actor-predestroy-view :reader actor-predestroy-view
                           :initform (au:dict #'eq))
   (%actor-preinit-db :reader actor-preinit-db
                      :initform (au:dict #'eq))
   (%actor-init-db :reader actor-init-db
                   :initform (au:dict #'eq))
   (%actor-active-db :reader actor-active-db
                     :initform (au:dict #'eq))
   (%actor-destroy-db :reader actor-destroy-db
                      :initform (au:dict #'eq))))

(defun pending-preinit-tasks-p (core-state)
  "Return T if there are ANY components or actors in the preinit data structures in CORE-STATE."
  (or (plusp (hash-table-count (actor-preinit-db (tables core-state))))
      (block done
        (au:do-hash-values (v (component-preinit-by-type-view (tables core-state)))
          (when (plusp (hash-table-count v))
            (return-from done t))))))

(defun pending-predestroy-tasks-p (core-state)
  "Return T if there are ANY components or actors that are in the predestroy data structures in
CORE-STATE."
  (or (plusp (hash-table-count (component-predestroy-view (tables core-state))))
      (plusp (hash-table-count (actor-predestroy-view (tables core-state))))))

(defun pending-destroy-tasks-p (core-state)
  "Return T of there are ANY components or actors that are in the destroy data structures in
CORE-STATE."
  (or (plusp (hash-table-count (actor-destroy-db (tables core-state))))
      (block done
        (au:do-hash-values (v (component-destroy-by-type-view (tables core-state)))
          (when (plusp (hash-table-count v))
            (return-from done t))))))

(defun %make-scene-tree (core-state)
  (let* ((context (context core-state))
         (actor (make-actor context :id (au:unique-name '@universe)))
         (transform (make-component context 'transform :actor actor)))
    (attach-component actor transform)
    (spawn-actor actor :parent nil)
    (execute-flow core-state :default
                  'initialize-phase
                  'entry/initialize-phase
                  :come-from-state-name 'ef-make-scene-tree)
    actor))

(defgeneric shared-storage (context key)
  (:method (context key)
    (au:href (shared-storage-table context) key))
  (:method (context (key component))
    (shared-storage context (component-type key))))

(defgeneric (setf shared-storage) (value context key)
  (:method (value context key)
    (setf (au:href (shared-storage-table context) key) value))
  (:method (value context (key component))
    (setf (shared-storage context (component-type key)) value)))

;;; Interim caching code for (often) resources. Uses nested hash tables like the shared-storage for
;;; components.
;;; TODO: change this when the real cache code shows up.

(defgeneric rcache-layout (entry-type)
  (:method ((entry-type symbol))
    '(eql)))

(defgeneric rcache-lookup (context entry-type &rest keys)
  (:method ((entry-type symbol) context &rest keys)
    (apply #'rcache-lookup entry-type context keys)))

(defgeneric rcache-construct (context entry-type &rest keys)
  (:method ((entry-type symbol) context &rest keys)
    (apply #'rcache-construct entry-type context keys)))

(defgeneric rcache-remove (context entry-type &rest keys)
  (:method ((entry-type symbol) context &rest keys)
    (apply #'rcache-remove entry-type context keys)))

(defgeneric rcache-dispose (context entry-type removed-value)
  (:method ((entry-type symbol) context removed-value)
    (rcache-dispose entry-type context removed-value)))

;; This might call rcache-construct if needed.
(defmethod rcache-lookup (context (entry-type symbol)
                          &rest keys)
  (let ((core-state (core-state context)))
    (ensure-nested-hash-table (rcache core-state)
                              ;; NOTE: 'eq is for the rcache table itself.
                              (list* 'eq (rcache-layout entry-type))
                              (list* entry-type keys))
    (multiple-value-bind (value presentp)
        (apply #'au:href (rcache core-state) (list* entry-type keys))
      (unless presentp
        (setf value (apply #'rcache-construct context entry-type keys)
              (apply #'au:href (rcache core-state) (list* entry-type keys)) value))
      value)))

;; This might call rcache-dispose if needed.
(defmethod rcache-remove (context (entry-type symbol) &rest keys)
  (let ((core-state (core-state context)))
    (multiple-value-bind (value presentp)
        (apply #'au:href (rcache core-state) (list* entry-type keys))
      (when presentp
        (remhash (apply #'au:href (rcache core-state) (list* entry-type keys))
                 (rcache core-state))
        (rcache-dispose context entry-type value)))))
