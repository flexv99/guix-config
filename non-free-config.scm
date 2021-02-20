(define-module (my packages)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages linux)
  #:use-module (guix build-system trivial)
  #:use-module (gnu)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix packages))

(define (linux-nonfree-urls version)
  "Return a list of URLs for Linux-Nonfree VERSION."
  (list (string-append
         "https://www.kernel.org/pub/linux/kernel/v4.x/"
         "linux-" version ".tar.xz")))

;; Remove this and native-inputs below to use the default config from Guix.
;; Make sure the kernel minor version matches, though.
(define kernel-config
  (string-append (dirname (current-filename)) "/kernel.config"))

(define-public linux-nonfree
  (package
    (inherit linux-libre)
    (name "linux-nonfree")
    (version "4.13.11")
    (source (origin
              (method url-fetch)
              (uri (linux-nonfree-urls version))
              (sha256
               (base32
                "1vzl2i72c8iidhdc8a490npsbk7q7iphjqil4i9609disqw75gx4"))))
    (native-inputs
     `(("kconfig" ,kernel-config)
       ,@(alist-delete "kconfig"
                       (package-native-inputs linux-libre))))
    (synopsis "Mainline Linux kernel, nonfree binary blobs included")
    (description "Linux is a kernel.")
    (license license:gpl2)              ;XXX with proprietary firmware
    (home-page "https://kernel.org")))

(define (linux-firmware-version) "9d40a17beaf271e6ad47a5e714a296100eef4692")
(define (linux-firmware-source version)
  (origin
    (method git-fetch)
    (uri (git-reference
          (url (string-append "https://git.kernel.org/pub/scm/linux/kernel"
                              "/git/firmware/linux-firmware.git"))
          (commit version)))
    (file-name (string-append "linux-firmware-" version "-checkout"))
    (sha256
     (base32
      "099kll2n1zvps5qawnbm6c75khgn81j8ns0widiw0lnwm8s9q6ch"))))

(define-public iwlwifi-firmware-nonfree
  (package
    (name "iwlwifi-firmware-nonfree")
    (version (linux-firmware-version))
    (source (linux-firmware-source version))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder (begin
                   (use-modules (guix build utils))
                   (let ((source (assoc-ref %build-inputs "source"))
                         (fw-dir (string-append %output "/lib/firmware/")))
                     (mkdir-p fw-dir)
                     (for-each (lambda (file)
                                 (copy-file file
                                            (string-append fw-dir (basename file))))
                               (find-files source
                                           "iwlwifi-.*\\.ucode$|LICENSE\\.iwlwifi_firmware$"))
                     #t))))
    (home-page "https://wireless.wiki.kernel.org/en/users/drivers/iwlwifi")
    (synopsis "Non-free firmware for Intel wifi chips")
    (description "Non-free iwlwifi firmware")
    (license (license:non-copyleft
              "https://git.kernel.org/cgit/linux/kernel/git/firmware/linux-firmware.git/tree/LICENCE.iwlwifi_firmware?id=HEAD"))))



(define %sysctl-activation-service
  (simple-service 'sysctl activation-service-type
		  #~(let ((sysctl
			   (lambda (str)
			     (zero? (apply system*
					   #$(file-append procps
							  "/sbin/sysctl")
					   "-w" (string-tokenize str))))))
		      (and
		       ;; Enable IPv6 privacy extensions.
		       (sysctl "net.ipv6.conf.eth0.use_tempaddr=2")
		       ;; Enable SYN cookie protection.
		       (sysctl "net.ipv4.tcp_syncookies=1")
		       ;; Log Martian packets.
		       (sysctl "net.ipv4.conf.default.log_martians=1")))))

(define %powertop-service
  (simple-service 'powertop activation-service-type
		  #~(zero? (system* #$(file-append powertop "/sbin/powertop")
				    "--auto-tune"))))

(use-modules (gnu)
             (guix store)               ;for %default-substitute-urls
             (gnu system nss)
             (my packages)
             (srfi srfi-1))
(use-service-modules admin base dbus desktop mcron networking ssh xorg sddm)
(use-package-modules admin bootloaders certs disk fonts file emacs
                     libusb linux version-control
                     ssh tls tmux wm xdisorg xorg)

(use-modules (gnu)
	     (gnu packages)
             (gnu system nss))
(use-service-modules desktop networking ssh xorg)

(operating-system
 (locale "en_GB.utf8")
 (timezone "Europe/Rome")
 (keyboard-layout (keyboard-layout "gb"))
 (host-name "flex")
 (kernel linux-nonfree)
 (kernel-arguments '("modprobe.blacklist=pcspkr,snd_pcsp"))
 (firmware (append (list
                    iwlwifi-firmware-nonfree)
                   %base-firmware))
 (users (cons* (user-account
                (name "flex")
                (comment "flex")
                (group "users")
                (home-directory "/home/flex")
                (supplementary-groups
                 '("wheel" "netdev" "audio" "video")))
               %base-user-accounts))
 (packages
  (append (map specification->package
	       '("emacs" "emacs-exwm"
		 "emacs-desktop-environment"
		 "nss-certs" "xmonad" "ghc-xmonad-contrib"
		 "xmobar" "git" "st"))
	  %base-packages))
 (services
  (append
   (list (service openssh-service-type)
         (service tor-service-type)
         (set-xorg-configuration
          (xorg-configuration
           (keyboard-layout keyboard-layout))))
   %desktop-services))
 (bootloader
  (bootloader-configuration
   (bootloader grub-bootloader)
   (target "/dev/sda")
   (keyboard-layout keyboard-layout)))
 (swap-devices
  (list (uuid "0a477c55-5219-42c9-b5d9-2384ee703d27")))
 (file-systems
  (cons* (file-system
          (mount-point "/")
          (device
           (uuid "20d060a0-a4e7-4962-8835-6d3056694243"
                 'ext4))
          (type "ext4"))
         %base-file-systems)))
