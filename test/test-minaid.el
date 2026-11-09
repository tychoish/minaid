;;; test-minaid.el --- ERT tests for minaid.el -*- lexical-binding: t; no-byte-compile: t; -*-

(require 'ert)
(let* ((test-file (or load-file-name buffer-file-name))
       (test-dir (file-name-directory test-file))
       (root (file-name-directory (directory-file-name test-dir))))
  (add-to-list 'load-path root))
(require 'cl-lib)
(require 'minaid)
(require 'comint)
(require 'corfu-quick)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Alias and Keymap Tests

(ert-deftest minaid-test/minaid-map-alias ()
  "Test that minaid-map aliases minaid-completion-map, and all keymaps are defined."
  (should (boundp 'minaid-completion-map))
  (should (boundp 'minaid-map))
  (should (eq minaid-map minaid-completion-map))
  (should (boundp 'minaid-consult-map))
  (should (boundp 'minaid-consult-search-map))
  (should (boundp 'minaid-global-map)))

(ert-deftest minaid-test/completion-bindings-installed ()
  "Test that completion bindings are registered top-level in minaid keymaps."
  (should (eq (keymap-lookup minaid-completion-map "TAB") #'completion-at-point))
  (should (eq (keymap-lookup minaid-completion-map "/") #'dabbrev-expand))
  (should (eq (keymap-lookup minaid-completion-map "c") #'dabbrev-completion))
  (should (eq (keymap-lookup minaid-completion-map "i") #'tempel-insert))
  (should (eq (keymap-lookup minaid-completion-map "d") #'cape-dabbrev))
  (should (eq (keymap-lookup minaid-completion-map "h") #'cape-history))
  (should (eq (keymap-lookup minaid-completion-map "f") #'cape-file))
  (should (eq (keymap-lookup minaid-completion-map ";") #'minaid-corfu-at-point))
  ;; Search submap mounted under minaid-consult-map "s"
  (should (eq (keymap-lookup minaid-consult-map "s l") #'consult-line))
  (should (eq (keymap-lookup minaid-consult-map "s m") #'consult-line-multi))
  (should (eq (keymap-lookup minaid-consult-map "s k") #'consult-keep-lines))
  (should (eq (keymap-lookup minaid-consult-map "s f") #'consult-focus-lines))
  (should (eq (keymap-lookup minaid-consult-map "t") #'tempel-insert))
  (should (eq (keymap-lookup minaid-consult-map "h") #'consult-history))
  (should (eq (keymap-lookup minaid-consult-map "d") #'grepx-live-pwd))
  (should (eq (keymap-lookup minaid-consult-map "r") #'grepx-live))
  (should (eq (keymap-lookup minaid-consult-map "g") #'grepx-project))
  (should (eq (keymap-lookup minaid-consult-map "m") #'grepx-menu))
  (should (eq (keymap-lookup minaid-consult-map "f") #'consult-flyspell))
  (should (eq (keymap-lookup minaid-consult-map "c") #'consult-flycheck))
  (should (eq (keymap-lookup minaid-consult-search-map "l") #'consult-line))
  (should (eq (keymap-lookup minaid-consult-search-map "r") #'grepx-live))
  (should (eq (keymap-lookup minaid-consult-search-map "g") #'grepx-project))
  (should (eq (keymap-lookup minaid-consult-search-map "d") #'grepx-directory))
  (should (eq (keymap-lookup minaid-consult-search-map "?") #'grepx-menu))
  (should (eq (keymap-lookup minaid-global-map "C-.") #'embark-act))
  (should (eq (keymap-lookup minaid-global-map "C-x b") #'consult-buffer))
  (should (eq (keymap-lookup minaid-global-map "M-g r") #'grepx-live))
  (should (eq (keymap-lookup minaid-global-map "M-s r") #'grepx-live))
  (should (eq (keymap-lookup minaid-global-map "M-s g") #'grepx-project))
  (should (eq (keymap-lookup minaid-global-map "M-s d") #'grepx-directory))
  (should (eq (keymap-lookup minaid-global-map "M-s f") #'minaid-consult-find-at-point))
  (should (eq (keymap-lookup minaid-global-map "M-s m") #'grepx-menu)))

(ert-deftest minaid-test/corfu-quick-bindings-installed ()
  "Test that corfu-quick functions are bound and defined in corfu-map."
  (should (fboundp 'corfu-quick-jump))
  (should (fboundp 'corfu-quick-complete))
  (should (fboundp 'corfu-quick-insert))
  (let ((was-on minaid-mode))
    (unwind-protect
        (progn
          (unless was-on (minaid-mode 1))
          (should (eq (keymap-lookup corfu-map "C-j") #'corfu-quick-jump))
          (should (eq (keymap-lookup corfu-map "C-<tab>") #'corfu-quick-complete))
          (should (eq (keymap-lookup corfu-map "C-<return>") #'corfu-quick-insert)))
      (unless was-on
        (minaid-mode -1)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Mode Lifecycle Tests

(ert-deftest minaid-test/lifecycle-toggle ()
  "Test that enabling and disabling minaid-mode toggles settings symmetrically."
  (let ((was-on minaid-mode))
    (unwind-protect
        (progn
          (when was-on
            (minaid-mode -1))
          (let ((orig-styles completion-styles)
                (orig-overrides completion-category-overrides)
                (orig-xref-xrefs (and (boundp 'xref-show-xrefs-function) xref-show-xrefs-function))
                (orig-xref-defs (and (boundp 'xref-show-definitions-function) xref-show-definitions-function))
                (orig-marginalia-hooks (copy-sequence marginalia-mode-hook))
                (orig-corfu-hooks (copy-sequence corfu-mode-hook)))
            ;; Enable mode
            (minaid-mode 1)
            (should minaid-mode)
            (should global-corfu-mode)
            (should (equal completion-styles '(orderless basic)))
            (should (assq 'file completion-category-overrides))
            (should (eq xref-show-xrefs-function 'consult-xref))
            (should (eq xref-show-definitions-function 'consult-xref))
            (should (memq #'minaid-elisp-capf-setup emacs-lisp-mode-hook))
            (should (memq #'minaid-corfu-prog-mode-setup prog-mode-hook))
            (should (memq #'minaid-corfu-prog-mode-setup comint-mode-hook))
            (should (memq #'minaid-corfu-agent-shell-setup agent-shell-mode-hook))
            (should (memq #'minaid-load-abbrev-files abbrev-mode-hook))
            (should (eq (lookup-key minaid-mode-map (kbd "C-.")) #'embark-act))

            ;; Disable mode
            (minaid-mode -1)
            (should-not minaid-mode)
            (should-not global-corfu-mode)
            (should (equal completion-styles orig-styles))
            (should (equal completion-category-overrides orig-overrides))
            (should (eq xref-show-xrefs-function orig-xref-xrefs))
            (should (eq xref-show-definitions-function orig-xref-defs))
            (should-not (memq #'minaid-elisp-capf-setup emacs-lisp-mode-hook))
            (should-not (memq #'minaid-corfu-prog-mode-setup prog-mode-hook))
            (should-not (memq #'minaid-corfu-prog-mode-setup comint-mode-hook))
            (should-not (memq #'minaid-corfu-agent-shell-setup agent-shell-mode-hook))
            (should-not (memq #'minaid-load-abbrev-files abbrev-mode-hook))
            (should-not (memq #'corfu-history-mode corfu-mode-hook))
            (should-not (memq #'corfu-indexed-mode corfu-mode-hook))
            (should-not (memq #'corfu-popupinfo-mode corfu-mode-hook))))
      (if was-on
          (minaid-mode 1)
        (when minaid-mode
          (minaid-mode -1))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Capf Configuration & Dispatch Tests

(defun test--dummy-wrapper (inner)
  (lambda () (cons 'wrapped (funcall inner))))

(defun test--dummy-inner ()
  'test-result)

(ert-deftest minaid-test/enable-sets-tempel-path ()
  "Enabling `minaid-mode' points `tempel-path' at `minaid-tempel-directory'."
  (let ((was-on minaid-mode))
    (unwind-protect
        (let ((minaid-tempel-directory "/tmp/minaid-templates"))
          (minaid-mode -1)
          (minaid-mode 1)
          (should (equal tempel-path "/tmp/minaid-templates")))
      (if was-on
          (progn
            (minaid-mode -1)
            (minaid-mode 1))
        (minaid-mode -1)))))

(ert-deftest minaid-test/open-custom-template-file-uses-directory ()
  "The template opener visits `minaid-tempel-directory'."
  (let ((minaid-tempel-directory "/tmp/minaid-templates")
        (opened nil))
    (cl-letf (((symbol-function 'find-file) (lambda (f) (setq opened f))))
      (minaid-open-custom-template-file))
    (should (equal opened "/tmp/minaid-templates"))))

(ert-deftest minaid-test/dabbrev-settings-lifecycle ()
  "Test that minaid configures dabbrev ignore filters symmetrically."
  (require 'dabbrev)
  (let ((orig-regexps (copy-sequence dabbrev-ignored-buffer-regexps))
        (orig-modes (copy-sequence dabbrev-ignored-buffer-modes))
        (minaid--saved-dabbrev-settings nil))
    (minaid--configure-dabbrev)
    (should (member "\\` " dabbrev-ignored-buffer-regexps))
    (should (memq 'authinfo-mode dabbrev-ignored-buffer-modes))
    (should (memq 'doc-view-mode dabbrev-ignored-buffer-modes))
    (should (memq 'pdf-view-mode dabbrev-ignored-buffer-modes))
    (should (memq 'tags-table-mode dabbrev-ignored-buffer-modes))
    (minaid--restore-dabbrev)
    (should (equal dabbrev-ignored-buffer-regexps orig-regexps))
    (should (equal dabbrev-ignored-buffer-modes orig-modes))))

(ert-deftest minaid-test/abbrev-files-cache-and-load ()
  "Test that `minaid-load-abbrev-files' caches and reads definitions."
  (let* ((tmp-dir (make-temp-file "minaid-abbrev-" t))
         (abbrev-file (file-name-concat tmp-dir "test-abbrev.el"))
         (minaid-abbrev-files-cache (make-hash-table :test #'equal)))
    (unwind-protect
        (progn
          (with-temp-file abbrev-file
            (insert ";; test abbrev\n"))
          (should (minaid-should-read-abbrev-file-p abbrev-file))
          (minaid-load-abbrev-files tmp-dir)
          (should (map-contains-key minaid-abbrev-files-cache abbrev-file))
          (should-not (minaid-should-read-abbrev-file-p abbrev-file)))
      (delete-directory tmp-dir t))))

(ert-deftest minaid-test/minaid-cape-capf-wrapper ()
  "Test that minaid-cape-capf-wrapper wraps the inner function cleanly without macro expansion."
  (let ((wrapped (minaid-cape-capf-wrapper #'test--dummy-wrapper #'test--dummy-inner)))
    (should (functionp wrapped))
    (should (equal (funcall wrapped) '(wrapped . test-result)))))

(ert-deftest minaid-test/setup-capfs-elisp ()
  "Test setup-capfs in an emacs-lisp-mode buffer."
  (with-temp-buffer
    (emacs-lisp-mode)
    (minaid-elisp-capf-setup)
    (should (memq #'cape-elisp-symbol completion-at-point-functions))
    (should (memq #'tempel-complete completion-at-point-functions))
    (should (memq #'cape-dabbrev completion-at-point-functions))))

(ert-deftest minaid-test/setup-capfs-prog ()
  "Test setup-capfs in a prog-mode buffer."
  (with-temp-buffer
    (prog-mode)
    (minaid-prog-mode-capf-setup)
    (should (memq #'tempel-complete completion-at-point-functions))
    (should (memq #'cape-file completion-at-point-functions))
    (should (memq #'cape-dabbrev completion-at-point-functions))))

(ert-deftest minaid-test/setup-capfs-text ()
  "Test setup-capfs in a text-mode buffer."
  (with-temp-buffer
    (text-mode)
    (minaid-text-mode-capf-setup)
    (should (memq #'tempel-complete completion-at-point-functions))
    (should (memq #'cape-file completion-at-point-functions))
    (should (memq #'cape-dabbrev completion-at-point-functions))))

(ert-deftest minaid-test/setup-capfs-eglot-minor-mode-detection ()
  "Test that setup-capfs detects bound-and-true-p eglot--managed-mode."
  (with-temp-buffer
    (prog-mode)
    (setq-local eglot--managed-mode t)
    (minaid-setup-capfs)
    ;; Should have configured eglot capf, not plain prog-mode capf
    (should (assq 'completion-category-defaults (buffer-local-variables)))
    (should (memq #'tempel-complete completion-at-point-functions))
    (should (memq #'cape-dabbrev completion-at-point-functions))))

(ert-deftest minaid-test/eglot-capf-setup-cape-wrap-buster ()
  "Test that minaid-eglot-capf-setup wraps eglot-completion-at-point directly."
  (with-temp-buffer
    (minaid-eglot-capf-setup)
    (should completion-at-point-functions)
    ;; The first function is either eglot-completion-at-point or a cape-wrap-buster closure
    (let ((first-capf (car completion-at-point-functions)))
      (should (functionp first-capf)))))

(ert-deftest minaid-test/setup-capfs-non-file-buffer-error ()
  "Test that setup-capfs signals user-error when buffer is not visiting a file."
  (with-temp-buffer
    ;; Fundamental-mode buffer without a file
    (setq-local buffer-file-name nil)
    (should-error (minaid-setup-capfs) :type 'user-error)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Corfu Hook Tests

(ert-deftest minaid-test/corfu-mode-prefixes ()
  "Test corfu auto prefixes in text vs prog modes."
  (with-temp-buffer
    (minaid-corfu-text-mode-setup)
    (should (= corfu-auto-prefix 2)))
  (with-temp-buffer
    (minaid-corfu-prog-mode-setup)
    (should (= corfu-auto-prefix 3))))

(ert-deftest minaid-test/corfu-agent-shell-setup ()
  "Test that agent-shell corfu setup disables ambient auto-completion."
  (with-temp-buffer
    (minaid-corfu-agent-shell-setup)
    (should corfu-mode)
    (should-not corfu-auto)
    (should corfu-quit-no-match)
    (should corfu-quit-at-boundary)))

(ert-deftest minaid-test/corfu-enabled-in-all-buffers ()
  "Test that minaid-mode enables corfu in text, prog, fundamental, comint buffers."
  (let ((noninteractive nil)
        (was-on minaid-mode))
    (unwind-protect
        (progn
          (unless was-on (minaid-mode 1))
          (dolist (mode '(fundamental-mode text-mode prog-mode comint-mode))
            (let ((buf (generate-new-buffer (format "test-corfu-%s" mode))))
              (unwind-protect
                  (with-current-buffer buf
                    (funcall mode)
                    (should corfu-mode))
                (kill-buffer buf)))))
      (unless was-on
        (minaid-mode -1)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Completion In-Region Wrapper Tests

(ert-deftest minaid-test/minaid-corfu-at-point-handler ()
  "Test that corfu-at-point binds completion-in-region-function."
  (let ((invoked nil))
    (cl-letf (((symbol-function 'completion-at-point)
               (lambda ()
                 (setq invoked completion-in-region-function))))
      (minaid-corfu-at-point)
      (should (eq invoked #'corfu--in-region)))))

(ert-deftest minaid-test/minaid-consult-at-point-handler ()
  "Test that consult-at-point binds completion-in-region-function."
  (let ((invoked nil))
    (cl-letf (((symbol-function 'completion-at-point)
               (lambda ()
                 (setq invoked completion-in-region-function))))
      (minaid-consult-at-point)
      (should (eq invoked #'consult-completion-in-region)))))


(ert-deftest minaid-test/minibuffer-and-isearch-bindings ()
  "Test that minaid binds built-in isearch-mode-map at top level."
  (should (eq (lookup-key isearch-mode-map (kbd "M-e")) #'consult-isearch-history))
  (should (eq (lookup-key isearch-mode-map (kbd "M-s e")) #'consult-isearch-history))
  (should (eq (lookup-key isearch-mode-map (kbd "M-s l")) #'consult-line))
  (should (eq (lookup-key isearch-mode-map (kbd "M-s L")) #'consult-line-multi)))

(ert-deftest minaid-test/hud-docs-map-bindings-in-hud-mode ()
  "Test that hud-docs-map in hud-mode binds documentation commands when hud-mode is present."
  (if (require 'hud-mode nil t)
      (progn
        (should (eq (lookup-key hud-docs-map "i") #'consult-info))
        (should (eq (lookup-key hud-docs-map "m") #'consult-man))
        (should (eq (lookup-key hud-docs-map "a") #'consult-eglot-symbols)))
    (ert-skip "hud-mode not available in load-path")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Minibuffer binding ownership

(defmacro minaid-test--with-clean-minibuffer-map (&rest body)
  "Run BODY with a scratch `minibuffer-local-map' and fresh saved state."
  (declare (indent 0))
  `(let ((minibuffer-local-map (make-sparse-keymap))
         (minaid--saved-minibuffer-bindings nil))
     ,@body))

(ert-deftest minaid-test/minibuffer-bindings-not-set-by-load ()
  "Loading minaid alone leaves minibuffer-local-map bindings unchanged."
  (let* ((emacs (expand-file-name invocation-name invocation-directory))
         (root (file-name-directory (locate-library "minaid")))
         (form "(princ (mapcar (lambda (k) (keymap-lookup minibuffer-local-map k)) '(\"C-g\" \"C-l\" \"C-c a\" \"M-s\" \"M-r\")))")
         (run (lambda (&rest args)
                (with-output-to-string
                  (with-current-buffer standard-output
                    (apply #'call-process emacs nil t nil "--batch" "-Q"
                           (append (list "-L" root)
                                   (seq-mapcat (lambda (dir) (list "-L" dir))
                                               (seq-filter #'stringp load-path))
                                   args (list "--eval" form))))))))
    (should (equal (funcall run)
                   (funcall run "--eval" "(require 'minaid)")))))

(ert-deftest minaid-test/minibuffer-bindings-round-trip ()
  "Install sets the contract; restore brings back prior definitions."
  (minaid-test--with-clean-minibuffer-map
    (keymap-set minibuffer-local-map "C-g" #'ignore)
    (keymap-set minibuffer-local-map "C-c a" #'ignore)
    (minaid--install-minibuffer-bindings)
    (should (eq (keymap-lookup minibuffer-local-map "C-g") #'minibuffer-keyboard-quit))
    (should (eq (keymap-lookup minibuffer-local-map "C-l") #'backward-kill-word))
    (should (eq (keymap-lookup minibuffer-local-map "C-c a") #'marginalia-cycle))
    (minaid--restore-minibuffer-bindings)
    (should (eq (keymap-lookup minibuffer-local-map "C-g") #'ignore))
    (should (eq (keymap-lookup minibuffer-local-map "C-c a") #'ignore))
    (should-not (keymap-lookup minibuffer-local-map "C-l"))
    (should-not (keymap-lookup minibuffer-local-map "M-s"))
    (should-not minaid--saved-minibuffer-bindings)))

(ert-deftest minaid-test/minibuffer-bindings-no-double-ownership ()
  "A second install must not overwrite the saved prior definitions."
  (minaid-test--with-clean-minibuffer-map
    (keymap-set minibuffer-local-map "C-l" #'ignore)
    (minaid--install-minibuffer-bindings)
    (minaid--install-minibuffer-bindings)
    (minaid--restore-minibuffer-bindings)
    (should (eq (keymap-lookup minibuffer-local-map "C-l") #'ignore))
    (should (= 1 (length (seq-filter (lambda (b) (equal (car b) "C-c a"))
                                     minaid-minibuffer-bindings))))))

(ert-deftest minaid-test/minibuffer-quit-once ()
  "C-g is the standard quit command, invoked exactly once (matches hud wrapper)."
  (minaid-test--with-clean-minibuffer-map
    (minaid--install-minibuffer-bindings)
    (let ((calls nil)
          (command (keymap-lookup minibuffer-local-map "C-g")))
      (should (eq command #'minibuffer-keyboard-quit))
      (cl-letf (((symbol-function 'minibuffer-keyboard-quit)
                 (lambda () (push 'quit calls))))
        (funcall command))
      (should (equal calls '(quit))))))

(ert-deftest minaid-test/kill-transform-rejects-empty ()
  "Empty strings should be rejected by `minaid--kill-transform-reject-empty'."
  (should-not (minaid--kill-transform-reject-empty ""))
  (should (equal (minaid--kill-transform-reject-empty "hello") "hello")))

(ert-deftest minaid-test/minibuffer-and-completion-settings-lifecycle ()
  "Settings managed by `minaid-mode' are applied on enable and restored on teardown."
  (let ((was-on minaid-mode))
    (unwind-protect
        (progn
          (when was-on
            (minaid-mode -1))
          (let ((saved-recursive enable-recursive-minibuffers)
                (saved-cycle completion-cycle-threshold)
                (saved-ignore completion-ignore-case)
                (saved-buf-ignore read-buffer-completion-ignore-case)
                (saved-file-ignore read-file-name-completion-ignore-case)
                (saved-pred read-extended-command-predicate)
                (saved-ispell text-mode-ispell-word-completion)
                (saved-props minibuffer-prompt-properties)
                (saved-kill-transform (and (boundp 'kill-transform-function) kill-transform-function)))
            (minaid--configure-minibuffer)
            (should (eq enable-recursive-minibuffers t))
            (should (equal minibuffer-prompt-properties '(read-only t cursor-intangible t face minibuffer-prompt)))
            (should (eq text-mode-ispell-word-completion nil))
            (should (= completion-cycle-threshold 2))
            (should (eq completion-ignore-case t))
            (should (eq read-buffer-completion-ignore-case t))
            (should (eq read-file-name-completion-ignore-case t))
            (should (eq read-extended-command-predicate #'command-completion-default-include-p))
            (should (functionp kill-transform-function))
            (should-not (funcall kill-transform-function ""))
            (should (equal (funcall kill-transform-function "valid") "valid"))
            (minaid--restore-minibuffer)
            (should (eq enable-recursive-minibuffers saved-recursive))
            (should (eq completion-cycle-threshold saved-cycle))
            (should (eq completion-ignore-case saved-ignore))
            (should (eq read-buffer-completion-ignore-case saved-buf-ignore))
            (should (eq read-file-name-completion-ignore-case saved-file-ignore))
            (should (eq read-extended-command-predicate saved-pred))
            (should (eq text-mode-ispell-word-completion saved-ispell))
            (should (equal minibuffer-prompt-properties saved-props))
            (should (eq (and (boundp 'kill-transform-function) kill-transform-function)
                        saved-kill-transform))))
      (if was-on
          (minaid-mode 1)
        (when minaid-mode
          (minaid-mode -1))))))

(provide 'test-minaid)
;;; test-minaid.el ends here
