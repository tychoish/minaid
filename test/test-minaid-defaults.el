;;; test-minaid-defaults.el --- Settings lifecycle tests -*- lexical-binding: t; -*-
(require 'ert)
(require 'minaid)

(defvar minaid-test-setting 'original)

(ert-deftest minaid-settings-lifecycle ()
  (let ((minaid--saved-settings nil)
        (minaid-settings '((minaid-test-setting . nil)
                           (unbound-minaid-test-setting . new)))
        (minaid-test-setting 'original))
    (unwind-protect
        (progn
          (makunbound 'unbound-minaid-test-setting)
          (with-temp-buffer
            (setq-local minaid-test-setting 'local)
            (minaid--apply-settings)
            (should (eq minaid-test-setting 'local))
            (should-not (default-value 'minaid-test-setting))
            (should (eq (default-value 'unbound-minaid-test-setting) 'new))
            (minaid--restore-settings)
            (should (eq minaid-test-setting 'local)))
          (should (eq minaid-test-setting 'original))
          (should-not (default-boundp 'unbound-minaid-test-setting)))
      (minaid--restore-settings)
      (makunbound 'unbound-minaid-test-setting))))

(ert-deftest minaid-completion-settings-and-kill-transform ()
  (let ((minaid--saved-settings nil)
        (minaid--saved-minibuffer-settings nil)
        (minaid-settings '((completion-cycle-threshold . 7)
                           (completion-ignore-case . t)))
        (completion-cycle-threshold 3)
        (completion-ignore-case nil)
        (kill-transform-function #'upcase))
    (unwind-protect
        (progn
          (minaid--configure-minibuffer)
          (should (= (default-value 'completion-cycle-threshold) 7))
          (should (default-value 'completion-ignore-case))
          (should (equal (funcall (default-value 'kill-transform-function) "abc") "ABC"))
          (should-not (funcall (default-value 'kill-transform-function) ""))
          (minaid--restore-minibuffer)
          (should (= (default-value 'completion-cycle-threshold) 3))
          (should-not (default-value 'completion-ignore-case))
          (should (eq (default-value 'kill-transform-function) #'upcase)))
      (minaid--restore-minibuffer))))

(provide 'test-minaid-defaults)
;;; test-minaid-defaults.el ends here
