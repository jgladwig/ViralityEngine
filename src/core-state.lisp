(in-package :gear)

(defclass core-state ()
  ((%actor-initialize-db :accessor actor-initialize-db
                         :initarg :actor-initialize-db
                         :initform (make-hash-table))
   (%actor-initialize-thunks-db :accessor actor-initialize-thunks-db
                                :initarg :actor-initialize-thunks-db
                                :initform (make-hash-table))
   (%actor-active-db :accessor actor-active-db
                     :initarg :actor-active-db
                     :initform (make-hash-table))
   (%component-initialize-view :accessor component-initialize-view
                               :initarg :component-initialize-view
                               :initform (make-hash-table))
   (%component-active-view :accessor component-active-view
                           :initarg :component-active-view
                           :initform (make-hash-table))
   (%scene-tree :accessor scene-tree
                :initarg :scene-tree
                :initform NIL)))

(defun make-core-state (&rest initargs)
  (apply #'make-instance 'core-state initargs))

(defun add-scene-tree-root (core-state actor)
  (setf (scene-tree core-state) actor))

(defun add-initializing-actor (core-state actor initializer-thunk-list)
  (setf
   ;; Store initializing actor
   (gethash actor (actor-initialize-db core-state))
   actor

   ;; store the thunk that inits all components in this actor.
   (gethash actor (actor-initialize-thunks-db core-state))
   initializer-thunk-list)

  ;; Store all associated components for actor in initing view.
  (maphash
   (lambda (k v)
     (setf
      ;; Store component in initing view.
      (gethash k (component-initialize-view core-state)) v))
   (components actor))

  ;; TODO: PROBABLY store components in type hashes too so I can execute
  ;; the initializers in the right type order. But not implemented yet.

  )
