;; This is an operating system configuration generated
;; by the graphical installer.

(use-modules (gnu)
	     (gnu packages)
             (gnu system nss))
(use-service-modules desktop networking ssh xorg)

(operating-system
 (locale "en_GB.utf8")
 (timezone "Europe/Rome")
 (keyboard-layout (keyboard-layout "gb"))
 (host-name "flex")
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
