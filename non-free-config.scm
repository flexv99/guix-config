(define-module (my packages)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages tls)
  #:use-module (guix build-system trivial)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (gnu services)
  #:use-module (guix gexp))


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
  (let* ((version "5.4.15"))
    (package
      (inherit linux-libre)
      (name "linux-nonfree")
      (version version)
      (source (origin
                (method url-fetch)
                (uri (linux-nonfree-urls version))
                (sha256
                 (base32
                  "1ccldlwj89qd22cl06706w7xzm8n69m6kg8ic0s5ns0ghlpj41v4"))))
      (synopsis "Mainline Linux kernel, nonfree binary blobs included.")
      (description "Linux is a kernel.")
      (license license:gpl2)
      (home-page "http://kernel.org/"))))

(define-public linux-firmware-non-free
  (package
    (name "linux-firmware-non-free")
    (version "1eb2408c6feacccd10b02a49214745f15d1c6fb7")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git")
                    (commit version)))
              (sha256
               (base32
                "0256p99bqwf1d1s6gqnzpjcdmg6skcp1jzz64sd1p29xxrf0pzfa"))))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder (begin
                   (use-modules (guix build utils))
                   (let ((source (assoc-ref %build-inputs "source"))
                         (fw-dir (string-append %output "/lib/firmware/")))
                     (mkdir-p fw-dir)
                     (copy-recursively source fw-dir)
                     #t))))

    (home-page "")
    (synopsis "Non-free firmware for Linux")
    (description "Non-free firmware for Linux")
    ;; FIXME: What license?
    (license (license:non-copyleft "http://git.kernel.org/?p=linux/kernel/git/firmware/linux-firmware.git;a=blob_plain;f=LICENCE.radeon_firmware;hb=HEAD"))))

(define-public iwlwifi-firmware-nonfree
  (package
    (name "iwlwifi-firmware-nonfree")
    (version "65b1c68c63f974d72610db38dfae49861117cae2")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git")
                    (commit version)))
              (sha256
               (base32
                "1anr7fblxfcrfrrgq98kzy64yrwygc2wdgi47skdmjxhi3wbrvxz"))))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder (begin
                   (use-modules (guix build utils))
                   (let ((source (assoc-ref %build-inputs "source"))
                         (fw-dir (string-append %output "/lib/firmware")))
                     (mkdir-p fw-dir)
                     (for-each (lambda (file)
                                 (copy-file file
                                            (string-append fw-dir "/"
                                                           (basename file))))
                               (find-files source "iwlwifi-.*\\.ucode$|LICENCE\\.iwlwifi_firmware$"))
                     #t))))

    (home-page "https://wireless.wiki.kernel.org/en/users/drivers/iwlwifi")
    (synopsis "Non-free firmware for Intel wifi chips")
    (description "Non-free firmware for Intel wifi chips")
    ;; FIXME: What license?
    (license (license:non-copyleft "http://git.kernel.org/?p=linux/kernel/git/firmware/linux-firmware.git;a=blob_plain;f=LICENCE.iwlwifi_firmware;hb=HEAD"))))

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
