#!/bin/bash
SECUREBOOT_SIGN_KEY="/home/alucard/secure_boot/priv.key"
SECUREBOOT_SIGN_CERT="/home/alucard/secure_boot/custom_config/db.crt"

while true; do

echo "Bitte wählen Sie eine Aktion aus:"
echo "0) quit"
echo "1) efibootmgr drucken"
echo "2) Gentoo EFI schreiben"
echo "3) Windows EFI schreiben"
echo "4) Install and sign grub - grubx64.efi"
echo "5) Sign Kernel in /boot"

read -p "Ihre Auswahl: " auswahl

case $auswahl in
    0)
        echo "Quit!"
	break
	;;
    1)
	efibootmgr -v
        ;;
    2)
        echo "Gentoo EFI schreiben fuer gentoo und gentoo_backup"
        efibootmgr -c \
                -d /dev/nvme1n1 -p3 \
                -L "Gentoo EFI Stub" \
                --loader '\EFI\gentoo\bzImage.efi' \
                -u "root=/dev/mapper/vg0-root ro crypt_root=UUID=00405283-d58f-46c9-8f0b-24e2e6824d22 root=UUID=1a78cda6-2b7a-443a-b1eb-1b1d0092eaa4 dolvm quiet root_trim=yes keymap=de iommu=pt amd_iommu=on apparmor=1 security=apparmor quiet splash initrd=\EFI\gentoo\initramfs.CPIO"

        efibootmgr -c \
	-d /dev/nvme1n1 -p3 \
	-L "Gentoo EFI Stub (backup)" \
	--loader '\EFI\gentoo_backup\bzImage.efi' \
	-u "root=/dev/mapper/vg0-root ro crypt_root=UUID=00405283-d58f-46c9-8f0b-24e2e6824d22 root=UUID=1a78cda6-2b7a-443a-b1eb-1b1d0092eaa4 dolvm quiet root_trim=yes keymap=de iommu=pt amd_iommu=on apparmor=1 security=apparmor quiet splash initrd=\EFI\gentoo_backup\initramfs.CPIO"
        ;;
    3)
        echo "Windows EFI schreiben"
        efibootmgr -c -d /dev/nvme1n1 -p3 -L "Windows 11 Pro" --loader '\EFI\MICROSOFT\BOOT\BOOTMGFW.EFI'
        ;;
     4)
        echo "Install grub"
	# We need to export the public key so we can embed it in the GRUB executable.
	echo \"Export GPG Key\"
	gpg -o "/tmp/grub_gpg_public_key" --export "grub"

        grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=gentoo --disable-shim-lock --pubkey=/tmp/grub_gpg_public_key --modules="pgp gcry_sha512 gcry_rsa"
	
        rm "/tmp/grub_gpg_public_key"

	echo \"grubx64.efi signieren\"
	sbsign --key $SECUREBOOT_SIGN_KEY --cert $SECUREBOOT_SIGN_CERT -o /efi/EFI/gentoo/grubx64.efi /efi/EFI/gentoo/grubx64.efi
	echo \"grubx64.efi wurde gesigned\"
	sbverify --cert $SECUREBOOT_SIGN_CERT /efi/EFI/gentoo/grubx64.efi

        echo \"Schreibe neuen Boot-Entry fuer grubx64.efi \"
	efibootmgr -c -d /dev/nvme1n1 -p3 -L "Gentoo Grub" -l '\EFI\gentoo\grubx64.efi'

	sign_file_for_grub
	;;
    *)
        echo "Ungültige Eingabe"
        ;;
esac
done
