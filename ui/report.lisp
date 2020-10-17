(in-package #:kandria)

(defun generate-report-files ()
  (let ((save (make-instance 'save-state :filename "report")))
    (save-state +world+ save)
    (remove-if-not (lambda (a) (probe-file (second a)))
                   `(("log" ,(trial:logfile))
                     ("screenshot" ,(capture NIL :file (tempfile)))
                     ("savestate" ,(file save))))))

(defun find-user-id ()
  (error-or
   (format NIL "~a@steam [~a]"
           (call steam/steam-id T)
           (call steam/display-name T))
   "anonymous"))

(defun submit-report (&key (user (find-user-id)) (files (generate-report-files)) description)
  (handler-bind ((error (lambda (e)
                          (v:debug :kandria.report e)
                          (v:error :kandria.report "Failed to submit report: ~a" e))))
    (org.shirakumo.feedback.client:submit
     "kandria" user
     :version (version :kandria)
     :description description
     :attachments files
     :key "A61C1370-B410-4BE5-96DB-1A2744628063"
     :secret "0533AD22-7729-4D91-AD4B-3967F74AA078"
     :token "D794637E-314B-4CE3-9FCA-55A3CF95146D"
     :token-secret "B9743038-1661-49E2-B363-C174D0761289")))

(defclass report-input (alloy:window)
  ((description :initform "" :accessor description))
  (:default-initargs :title "Report a bug"
                     :extent (alloy:extent 0 0 500 300)
                     :minimizable NIL
                     :maximizable NIL))

(defmethod alloy:close ((input report-input))
  (unpause-game T (unit 'ui-pass T))
  (call-next-method))

(defmethod alloy:accept ((input report-input))
  (handler-bind ((error (lambda (e)
                          (v:error :kandria.report e)
                          (messagebox "Failed to gather and submit report:~%~a" e)
                          (continue e))))
    (with-simple-restart (continue "Ignore the failed report.")
      (submit-report :description (description input))
      (alloy:close input))))

(defmethod initialize-instance :after ((input report-input) &key)
  (let* ((layout (make-instance 'alloy:grid-layout :col-sizes '(T) :row-sizes '(T 30) :layout-parent input))
         (focus (make-instance 'alloy:focus-list :focus-parent input))
         (description (alloy:represent (slot-value input 'description) 'alloy:input-box
                                       :placeholder "Describe your feedback here"
                                       :layout-parent layout :focus-parent focus))
         (submit (alloy:represent "Submit" 'alloy:button
                                  :layout-parent layout :focus-parent focus)))
    (alloy:on alloy:activate (submit)
      (alloy:accept input))))

(defun standalone-error-handler (err)
  (when (deploy:deployed-p)
    (v:error :trial err)
    (v:fatal :trial "Encountered unhandled error in ~a, bailing." (bt:current-thread))
    (cond ((string/= "" (or (uiop:getenv "DEPLOY_DEBUG_BOOT") ""))
           (invoke-debugger err))
          ((ignore-errors (submit-report :description (format NIL "Hard crash due to error:~%~a" err)))
           (org.shirakumo.messagebox:show (format NIL "An unhandled error occurred. A log has been sent to the developers. Sorry for the inconvenience!")
                                          :title "Unhandled Error" :type :error :modal T))
          (T
           (org.shirakumo.messagebox:show (format NIL "An unhandled error occurred. Please send the application logfile to the developers. You can find it here:~%~%~a"
                                                  (uiop:native-namestring (logfile)))
                                          :title "Unhandled Error" :type :error :modal T)))
    (deploy:quit)))
