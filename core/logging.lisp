(in-package :%first-light)

(defun enable-logging (core-state)
  (let ((context (context core-state)))
    (unless (v:thread v:*global-controller*)
      (v:start v:*global-controller*))
    (when (option context :log-repl-enabled)
      (setf (v:repl-level) (option context :log-level)
            (v:repl-categories) (option context :log-repl-categories)))
    (u:when-let ((log-debug (find-resource context :log-debug)))
      (ensure-directories-exist log-debug)
      (v:define-pipe ()
        (v:level-filter :level :debug)
        (v:file-faucet :file log-debug)))
    (u:when-let ((log-error (find-resource context :log-error)))
      (ensure-directories-exist log-error)
      (v:define-pipe ()
        (v:level-filter :level :error)
        (v:file-faucet :file log-error)))))
