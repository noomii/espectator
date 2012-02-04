;;; enotify-espectator.el --- Enotify plugin per espectator (ruby TDD)
;;; part of espectator/rails-watchr-emacs

;; Copyright (C) 2012  Alessandro Piras

;; Author: Alessandro Piras <laynor@gmail.com>
;; Keywords: convenience
;; URL: http://www.github.com/laynor/espectator

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Installation: add this file to your load path and require it:
;; (add-to-list 'load-path "path/to/enotify-espectator/")
;; (require 'espectator)
;;
;; This plugin can take advantage of alert.el. If you want to enable
;; alert.el alerts, customize `enotify-espectator-use-alert' and ensure
;; alert.el is loaded before this file.

;;; Code:

(require 'enotify)

(defgroup enotify-espectator nil
  "Enotify plugin for espectator"
  :group 'enotify)

(defcustom enotify-espectator-use-alert nil
  "whether enotify-espectator should use alert.el"
  :group 'enotify-espectator
  :type '(choice (const :tag "No" nil) (const :tag "Yes" t)))

(defcustom enotify-espectator-alert-severity 'trivial
  "severity for alert.el alerts"
  :group 'enotify-espectator
  :type '(choice (const :tag "Urgent" urgent)
		 (const :tag "High" high)
		 (const :tag "Moderate" moderate)
		 (const :tag "Normal" normal)
		 (const :tag "Low" low)
		 (const :tag "Trivial" trivial)))

(defcustom enotify-espectator-alert-use-separate-log-buffers nil
  "whether enotify-espectator should use different alert log
buffers for each project."
  :group 'enotify-espectator
  :type '(choice (const :tag "No" nil)
		 (const :tag "Yes" t)))


(defcustom enotify-espectator-change-face-timeout nil
  "amount of seconds after which the notification face should be changed."
  :group 'enotify-espectator
  :type '(choice (const nil) integer))

(defcustom enotify-espectator-timeout-face :standard
  "face to apply to the notification text on timeout"
  :group 'enotify-espectator
  :type '(choice (const :tag "Standard enotify face" :standard )
		 (const :tag "Standard enotify success face" :success)
		 (const :tag "Standard enotify warning face" :warning)
		 (const :tag "Standard enotify failure face" :failure)
		 face))

(defcustom enotify-rspec-handler 'enotify-rspec-handler
  "Message handler for enotify espectator notifications.
This function should take 2 arguments, (id data), where id is the
enotify slot id, and data contains the rspec output.
The default handler just writes the results in a buffer in org-mode.")

(defvar enotify-rspec-result-message-handler 'enotify-rspec-result-message-handler
  "Don't touch me - used by espectator.")

(defvar enotify-rspec-mouse-1-handler 'enotify-rspec-mouse-1-handler
  "Mouse-1 handler function. It takes an event parameter. See enotify README for details.")



;;;; Alert.el stuff

(when (featurep 'alert)
  (defun enotify-espectator-alert-id (info)
    (car (plist-get info :data)))
  (defun enotify-espectator-alert-face (info)
    (enotify-face (cdr (plist-get info :data))))
  
  (defun enotify-espectator-chomp (str)
    "Chomp leading and tailing whitespace from STR."
    (while (string-match "\\`\n+\\|^\\s-+\\|\\s-+$\\|\n+\\'"
			 str)
      (setq str (replace-match "" t t str)))
    str) 
  
  (defun* enotify-espectator-colorized-summary (info &optional (with-timestamp t)) 
    (let* ((s+t (plist-get info :message))
	   (summary (if with-timestamp s+t (car (last (split-string s+t ":"))))))
      (enotify-espectator-chomp
       (propertize summary 'face (enotify-espectator-alert-face info)))))
  
  (defun enotify-espectator-alert-log (info)
    (let ((bname (format "*Alerts - Espectator [%s]*" (enotify-espectator-alert-id info))))
      (with-current-buffer
	  (get-buffer-create bname)
	(goto-char (point-max))
	(insert (format-time-string "%H:%M %p - ")
		(enotify-espectator-colorized-summary info nil)
		?\n))))
    
  (defun alert-espectator-notify (info)
    "alert.el notifier function for enotify-espectator."
    (when enotify-espectator-alert-use-separate-log-buffers
      (enotify-espectator-alert-log info))
    (message "%s: %s" 
	     (alert-colorize-message (format "Enotify - espectator [%s]:"
					     (enotify-espectator-alert-id info))
				     (plist-get info :severity))
	     (enotify-espectator-colorized-summary info)))
  
  ;;; enotify-espectator alert style
  (alert-define-style 'enotify-espectator
		      :title "Display message in minibuffer for enotify-espectator alerts"
		      :notifier #'alert-espectator-notify
		      :remover #'alert-message-remove)

  (defun enotify-espectator-summary (id)
    "Extract summary from enotify notifiations sent by espectator."
    (let* ((notification (enotify-mode-line-notification id))
	   (help-text (plist-get notification :help))
	   (face (enotify-face (plist-get notification :face)))
	   (summary-text (nth 1 (split-string help-text "\n"))))
      summary-text))
  
  
  (defun enotify-espectator-face (id)
    "Extracts the face used for the enotify notification sent by espectator"
    (enotify-face (plist-get (enotify-mode-line-notification id) :face)))
    
  ;;; Use enotify-espectator style for all the alerts whose category is enotify-espectator
  (alert-add-rule :predicate (lambda (info)
			       (eq (plist-get info :category)
				   'enotify-espectator))
		  :style 'enotify-espectator))


;;;; Enotify stuff

(defun enotify-rspec-result-buffer-name (id)
  (format "*RSpec Results: %s*" id))

(defun enotify-rspec-handler (id data)
  (let ((buf (get-buffer-create (enotify-rspec-result-buffer-name id))))
    (save-current-buffer
      (set-buffer buf)
      (erase-buffer)
      (insert data)
      (flet ((message (&rest args) (apply 'format args)))
	(org-mode)))))

(defun enotify-rspec-result-message-handler (id data)
  (when enotify-espectator-change-face-timeout
    (run-with-timer enotify-espectator-change-face-timeout nil
		    'enotify-change-notification-face
		    id enotify-espectator-timeout-face))
  (when (and enotify-espectator-use-alert (featurep 'alert))
    (let ((alert-log-messages (if enotify-espectator-alert-use-separate-log-buffers
				  nil
				alert-log-messages)))
      (alert (enotify-espectator-summary id)
	     :title id
	     :data (cons id (enotify-espectator-face id))
	     :category 'enotify-espectator
	     :severity enotify-espectator-alert-severity)))
  (funcall enotify-rspec-handler id data))


(defun enotify-rspec-mouse-1-handler (event)
  (interactive "e")
  (switch-to-buffer-other-window
   (enotify-rspec-result-buffer-name
    (enotify-event->slot-id event))))

(provide 'enotify-espectator)
;;; enotify-espectator.el ends here
