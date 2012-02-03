;;;; Espectator plugin for enotify
(require 'enotify)

(defgroup enotify-espectator nil
  "Enotify plugin for espectator"
  :group 'enotify)

(defcustom enotify-espectator-change-face-timeout nil
  "amount of seconds after which the notification face should be changed."
  :group 'enotify-espectator
  :type '(choice (const nil) integer))

(defcustom enotify-espectator-timeout-face :standard
  "face to apply to the notification text after
  `enotify-espectator-change-face-timeout' seconds passed"
  :group 'enotify-espectator
  :type '(choice (const :tag "Standard enotify face" :standard )
		 (const :tag "Standard enotify success face" :success)
		 (const :tag "Standard enotify warning face" :warning)
		 (const :tag "Standard enotify failure face" :failure)
		 face))

(defun enotify-rspec-result-buffer-name (id)
  (format "*RSpec Results: %s*" id))

(defun enotify-rspec-result-message-handler (id data)
  (when enotify-espectator-change-face-timeout
    (run-with-timer enotify-espectator-change-face-timeout nil
		    'enotify-change-notification-face
		    id enotify-espectator-timeout-face))
  (let ((buf (get-buffer-create (enotify-rspec-result-buffer-name id))))
    (save-current-buffer
      (set-buffer buf)
      (erase-buffer)
      (insert data)
      (flet ((message (&rest args) (apply 'format args)))
	(org-mode)))))

(defvar enotify-rspec-result-message-handler 'enotify-rspec-result-message-handler)

(defun enotify-rspec-mouse-1-handler (event)
  (interactive "e")
  (switch-to-buffer-other-window
   (enotify-rspec-result-buffer-name
    (enotify-event->slot-id event))))


(defvar enotify-rspec-mouse-1-handler 'enotify-rspec-mouse-1-handler)

(provide 'enotify-espectator)

