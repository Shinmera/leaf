(in-package #:org.shirakumo.fraf.leaf)

(defclass editor (base-editor)
  ((sidebar :initform NIL :accessor sidebar)))

;;; Update sidebar on class change
(defmethod update-instance-for-different-class :around ((editor editor) current &key)
  (when (sidebar editor)
    (let ((layout (alloy:root (alloy:layout-tree (ui editor))))
          (focus (alloy:root (alloy:focus-tree (ui editor)))))
      (alloy:leave (sidebar editor) layout)
      (alloy:leave (sidebar editor) focus))
    (when (typep current 'editor)
      (setf (sidebar current) NIL)))
  (call-next-method))

(defmethod update-instance-for-different-class :around (previous (editor editor) &key)
  (call-next-method)
  (when (sidebar editor)
    (let ((layout (alloy:root (alloy:layout-tree (ui editor))))
          (focus (alloy:root (alloy:focus-tree (ui editor)))))
      (alloy:enter (sidebar editor) layout :place :east)
      (alloy:enter (sidebar editor) focus)
      (alloy:register (sidebar editor) (ui editor)))))

(defun update-marker (editor entity)
  (if entity
      (let* ((p (location entity))
             (s (bsize entity))
             (ul (vec3 (- (vx p) (vx s)) (+ (vy p) (vy s)) 0))
             (ur (vec3 (+ (vx p) (vx s)) (+ (vy p) (vy s)) 0))
             (br (vec3 (+ (vx p) (vx s)) (- (vy p) (vy s)) 0))
             (bl (vec3 (- (vx p) (vx s)) (- (vy p) (vy s)) 0)))
        (replace-vertex-data (marker editor) (list ul ur ur br br bl bl ul) :default-color (vec 1 1 1 1)))
      (replace-vertex-data (marker editor) ())))

(defmethod active-p ((editor editor)) T)

(defmethod (setf entity) :after (value (editor editor))
  (typecase value
    (sized-entity
     (update-marker editor value))
    (T
     (update-marker editor NIL)))
  (change-class editor (editor-class value))
  (v:info :leaf.editor "Switched entity to ~a (~a)" value (type-of editor)))

(defmethod handle ((event event) (editor editor))
  (handle event (controller (handler *context*)))
  (handle event (unit :camera +world+))
  (unless (handle event (ui editor))
    (call-next-method)
    (handle event (cond ((retained :alt) (alt-tool editor))
                        (T (tool editor))))))

(defmethod render ((editor editor) target)
  (when (entity editor)
    (update-marker editor (entity editor)))
  (gl:blend-func :one-minus-dst-color :zero)
  (render (marker editor) target)
  (gl:blend-func :src-alpha :one-minus-src-alpha)
  (render (ui editor) target))

(defmethod alloy:handle ((event alloy:key-up) (ui editor-ui))
  (restart-case (call-next-method)
    (alloy:decline ()
      (let ((editor (unit :editor T))
            (camera (unit :camera T)))
        (case (alloy:key event)
          (:tab (setf (entity editor) NIL))
          (:f1 (edit 'save-region T))
          (:f2 (edit 'load-region T))
          (:f3 (edit 'save-game T))
          (:f4 (edit 'load-game T))
          (:f5)
          (:f6)
          (:f7)
          (:f8)
          (:f9)
          (:f10)
          (:f11)
          ;(:f12 (edit 'inspect T))
          (:c (edit 'clone-entity T))
          (:delete (edit 'delete-entity T))
          (:insert (edit 'insert-entity T))
          (:b (setf (tool editor) (make-instance 'browser :editor editor)))
          (:f (setf (tool editor) (make-instance 'freeform :editor editor)))
          (:p (setf (tool editor) (make-instance 'paint :editor editor)))
          ((:w :up) (incf (vy (location camera)) 5))
          ((:a :left) (decf (vx (location camera)) 5))
          ((:s :down) (decf (vy (location camera)) 5))
          ((:d :right) (incf (vx (location camera)) 5))
          (T (alloy:decline)))))))

(defmethod alloy:handle ((event alloy:pointer-up) (ui editor-ui))
  (restart-case (call-next-method)
    (alloy:decline ()
      (if (and (null (entity (unit :editor T))) (eq :left (alloy:kind event)))
          (let* ((pos (alloy:location event))
                 (pos (mouse-world-pos (vec (alloy:pxx pos) (alloy:pxy pos)))))
            (setf (entity (unit :editor T)) (entity-at-point pos +world+)))
          (alloy:decline)))))

(defmethod alloy:handle :before ((event alloy:pointer-move) (ui editor-ui))
  (when (null (entity (unit :editor T)))
    (let* ((pos (alloy:location event))
           (pos (mouse-world-pos (vec (alloy:pxx pos) (alloy:pxy pos))))
           (entity (entity-at-point pos +world+)))
      (update-marker (unit :editor T) entity))))

(defmethod edit (action (editor (eql T)))
  (edit action (unit :editor T)))

(defmethod edit ((action (eql 'load-region)) (editor editor))
  (let ((old (unit 'region +world+)))
    (cond ((retained :control)
           ;; FIXME: 
           ;; (transition old (load-region T T))
           )
          (T
           (let ((path (file-select:existing :title "Select Region File")))
             (when path
               ;; FIXME:
               ;; (transition old (load-region path T))
               ))))))

(defmethod edit ((action (eql 'save-region)) (editor editor))
  (if (retained :control)
      (let ((path (file-select:new :title "Select Region File" :default (storage (packet +world+)))))
        (save-region T path))
      (save-region T T)))

(defmethod edit ((action (eql 'save-game)) (editor editor))
  (save-state T T))

(defmethod edit ((action (eql 'load-game)) (editor editor))
  (let ((old (unit 'region +world+)))
    (flet ((load! (state)
             (load-state state T)
             ;; FIXME:
             ;; (transition old (unit 'region +world+))
             ))
      (cond ((retained :control) (load! T))
            (T (let ((path (file-select:existing :title "Select Save File" :default (file (state (handler *context*))))))
                 (load! path)))))))

(defmethod edit ((action (eql 'delete-entity)) (editor editor))
  (cl:block traverse
    (labels ((traverse (parent)
               (for:for ((unit over parent))
                 (cond ((eql unit (entity editor))
                        (leave (entity editor) parent)
                        (return-from traverse))
                       ((typep unit 'container)
                        (traverse unit))))))
      (traverse +world+)))
  (setf (entity editor) NIL))

(defmethod edit ((action (eql 'insert-entity)) (editor editor))
  (make-instance 'creator :ui (ui editor)))

(defmethod edit ((action (eql 'clone-entity)) (editor editor))
  (edit (make-instance 'insert-entity :entity (clone (entity editor))) editor))

(defmethod edit ((action (eql 'undo)) (editor editor))
  (undo editor (unit 'region T)))

(defmethod edit ((action (eql 'redo)) (editor editor))
  (redo editor (unit 'region T)))

#+(OR)
(defmethod edit ((action (eql 'inspect)) (editor editor))
  #+swank
  (let ((swank::*buffer-package* *package*)
        (swank::*buffer-readtable* *readtable*))
    (swank:inspect-in-emacs (entity editor) :wait NIL)))

(defclass insert-entity () ((entity :initarg :entity :initform (alloy:arg! :entity) :accessor entity)))

(defmethod edit ((action insert-entity) (editor editor))
  (let ((entity (entity action))
        (*package* #.*package*))
    (when (typep entity 'located-entity)
      (setf (location entity) (vcopy (location (unit :camera T)))))
    (enter-and-load entity (unit 'region T) (handler *context*))
    (setf (entity editor) entity)
    (setf (tool editor) (make-instance 'freeform :editor editor))))
