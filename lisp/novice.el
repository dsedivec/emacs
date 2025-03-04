;;; novice.el --- handling of disabled commands ("novice mode") for Emacs  -*- lexical-binding: t -*-

;; Copyright (C) 1985-1987, 1994, 2001-2025 Free Software Foundation,
;; Inc.

;; Maintainer: emacs-devel@gnu.org
;; Keywords: internal, help

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This mode provides a hook which is, by default, attached to various
;; putatively dangerous commands in a (probably futile) attempt to
;; prevent lusers from shooting themselves in the feet.

;;; Code:

;; This function is called (by autoloading)
;; to handle any disabled command.
;; The command is found in this-command
;; and the keys are returned by (this-command-keys).

;;;###autoload
(defvar disabled-command-function 'disabled-command-function
  "Function to call to handle disabled commands.
If nil, the feature is disabled, i.e., all commands work normally.")

;; It is ok here to assume that this-command is a symbol
;; because we won't get called otherwise.
;;;###autoload
(defun disabled-command-function (&optional cmd keys)
  (let* ((cmd (or cmd this-command))
         (keys (or keys (this-command-keys)))
         (help-string
          (concat
           (if (or (eq (aref keys 0)
                       (if (stringp keys)
                           (aref "\M-x" 0)
                         ?\M-x))
                   (and (>= (length keys) 2)
                        (eq (aref keys 0) meta-prefix-char)
                        (eq (aref keys 1) ?x)))
               (format "You have invoked the disabled command %s.\n" cmd)
             (substitute-command-keys
              (format "You have typed \\`%s', invoking disabled command %s.\n"
                      (key-description keys) cmd)))
           ;; Any special message saying why the command is disabled.
           (if (stringp (get cmd 'disabled))
               (get cmd 'disabled)
             (concat
              "It is disabled because new users often find it confusing.\n"
              (substitute-command-keys
               "Here's the first part of its description:\n\n")
              ;; Keep only the first paragraph of the documentation.
              (with-temp-buffer
                (insert (or (condition-case ()
			        (documentation cmd)
			      (error nil))
			    "<< not documented >>"))
                (goto-char (point-min))
                (when (search-forward "\n\n" nil t)
                  (delete-region (match-beginning 0) (point-max)))
                (indent-rigidly (point-min) (point-max) 3)
                (buffer-string))))
           (substitute-command-keys "\n
Do you want to use this command anyway?

You can now type:
 \\`n'    (also C-g) to cancel--don't try the command; it remains disabled.
 \\`y'    to enable the command (no questions if you use it again).
 \\`SPC'  to try the command just this once, but leave it disabled.
 \\`!'    to enable it and all the disabled commands for this session.")))
         (char
          ;; Note: the prompt produced from the choices below must not
          ;; overflow a single screen line, because otherwise it will
          ;; cause the mini-window to resize, which will in turn hide
          ;; the last line of the help text above: the code which fits
          ;; the window to the size of the help text does not expect
          ;; the mini-window to become taller.
          (car (read-multiple-choice "Use this command?"
                                     '((?n "no")
                                       (?y "yes")
                                       (?\s "(space bar) only once")
                                       (?! "use and enable all"))
                                     help-string
                                     "*Disabled Command*"))))
    (pcase char
      (?\C-g (setq quit-flag t))
      (?! (setq disabled-command-function nil))
      (?y
       (if (and user-init-file
                (not (string= "" user-init-file))
                (y-or-n-p "Enable command for future editing sessions also? "))
           (enable-command cmd)
         (put cmd 'disabled nil))))
    (unless (char-equal char ?n)
      (call-interactively cmd))))

(defun en/disable-command (command disable)
  (unless (commandp command)
    (error "Invalid command name `%s'" command))
  (put command 'disabled disable)
  (let ((init-file user-init-file)
	(default-init-file
	  (if (eq system-type 'ms-dos) "~/_emacs" "~/.emacs")))
    (unless init-file
      (if (or (file-exists-p default-init-file)
	      (and (eq system-type 'windows-nt)
		   (file-exists-p "~/_emacs")))
	  ;; Started with -q, i.e. the file containing
	  ;; enabled/disabled commands hasn't been read.  Saving
	  ;; settings there would overwrite other settings.
	  (error "Saving settings from \"emacs -q\" would overwrite existing customizations"))
      (setq init-file default-init-file)
      (if (and (not (file-exists-p init-file))
	       (eq system-type 'windows-nt)
	       (file-exists-p "~/_emacs"))
	  (setq init-file "~/_emacs")))
    (with-current-buffer (find-file-noselect
                          (substitute-in-file-name init-file))
      (goto-char (point-min))
      (if (search-forward (concat "(put '" (symbol-name command) " ") nil t)
	  (delete-region
	   (progn (beginning-of-line) (point))
	   (progn (forward-line 1) (point))))
      ;; Explicitly enable, in case this command is disabled by default
      ;; or in case the code we deleted was actually a comment.
      (goto-char (point-max))
      (unless (bolp) (newline))
      (insert "(put '" (symbol-name command) " 'disabled "
	      (symbol-name disable) ")\n")
      (save-buffer))))

;;;###autoload
(defun enable-command (command)
  "Allow COMMAND to be executed without special confirmation from now on.
COMMAND must be a symbol.
This command alters the user's .emacs file so that this will apply
to future sessions."
  (interactive "CEnable command: ")
  (en/disable-command command nil))

;;;###autoload
(defun disable-command (command)
  "Require special confirmation to execute COMMAND from now on.
COMMAND must be a symbol.
This command alters your init file so that this choice applies to
future sessions."
  (interactive "CDisable command: ")
  (en/disable-command command t))

(provide 'novice)

;;; novice.el ends here
