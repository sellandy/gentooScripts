#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Konfiguration
# ============================================================

KERNEL_DIR="/usr/src/linux"
BACKUP_DIR="/usr/src/.kernel_config_backups"
KERNEL_CONFIG="${KERNEL_DIR}/.config"

NITROKEY_SCRIPT="/etc/kernels/postbuild.d/20-nitrokey.sh"

# ============================================================
# Fehlerbehandlung
# ============================================================

trap 'echo "FEHLER in kernel-update.sh, Zeile $LINENO: $BASH_COMMAND" >&2' ERR

# ============================================================
# Funktionen
# ============================================================

yes_no_prompt() {
    local response

    while true; do
        read -r -p "$1 (ja/nein): " response || return 1

        case "${response,,}" in
            ja|j|yes|y)
                return 0
                ;;
            nein|n|no)
                return 1
                ;;
            *)
                echo "Bitte mit ja oder nein antworten."
                ;;
        esac
    done
}

abort() {
    echo "ABBRUCH: $1" >&2
    exit 1
}

# ============================================================
# Voraussetzungen prÃ¼fen
# ============================================================

if [[ $EUID -ne 0 ]]; then
    abort "Dieses Skript muss mit Root-Rechten ausgefÃ¼hrt werden (z. B. doas)."
fi

for cmd in eselect make diff date; do
    command -v "$cmd" >/dev/null 2>&1 ||
        abort "BenÃ¶tigtes Programm nicht gefunden: $cmd"
done

[[ -d "$KERNEL_DIR" ]] ||
    abort "Kernel-Verzeichnis nicht gefunden: $KERNEL_DIR"

[[ -f "$KERNEL_CONFIG" ]] ||
    abort "Keine Kernel-Konfiguration gefunden: $KERNEL_CONFIG"

[[ -x "$NITROKEY_SCRIPT" ]] ||
    abort "Nitrokey-Skript fehlt oder ist nicht ausfÃ¼hrbar: $NITROKEY_SCRIPT"

# ============================================================
# Systemstatus bestÃ¤tigen
# ============================================================

echo
echo "============================================================"
echo " Gentoo Kernel Update"
echo "============================================================"
echo

yes_no_prompt "Ist dein Gentoo-System vollstÃ¤ndig aktualisiert?" ||
    abort "Bitte zuerst das System aktualisieren."

# ============================================================
# Alte Kernel-Konfiguration sichern
# ============================================================

echo
echo "============================================================"
echo " Backup der Kernel-Konfiguration"
echo "============================================================"

mkdir -p "$BACKUP_DIR"

BACKUP_FILE="${BACKUP_DIR}/kernel_config_$(uname -r)_$(date +%Y%m%d-%H%M%S).config"

cp -a "$KERNEL_CONFIG" "$BACKUP_FILE"

echo "Konfiguration gesichert:"
echo "$BACKUP_FILE"

# ============================================================
# Kernel-Version auswÃ¤hlen
# ============================================================

echo
echo "============================================================"
echo " Kernel-Version auswÃ¤hlen"
echo "============================================================"

eselect kernel list

echo
read -r -p "Nummer des gewÃ¼nschten Kernels: " kernel_version

[[ "$kernel_version" =~ ^[0-9]+$ ]] ||
    abort "UngÃ¼ltige Kernel-Auswahl."

eselect kernel set "$kernel_version"

echo
echo "Aktiver Kernel-Quellbaum:"
readlink -f "$KERNEL_DIR"

# ============================================================
# Kernel-Verzeichnis vorbereiten
# ============================================================

echo
echo "============================================================"
echo " Kernel-Verzeichnis vorbereiten"
echo "============================================================"

cd "$KERNEL_DIR"

echo "Bereinige Kernel-Build-Verzeichnis..."
make clean

echo "Stelle bisherige Kernel-Konfiguration wieder her..."
cp -a "$BACKUP_FILE" "$KERNEL_CONFIG"

# ============================================================
# Neue Kernel-Konfiguration erzeugen
# ============================================================

echo
echo "============================================================"
echo " Kernel-Konfiguration aktualisieren"
echo "============================================================"

make olddefconfig

echo
echo "Vergleich der Kernel-Konfiguration:"
echo "Alt: $BACKUP_FILE"
echo "Neu: $KERNEL_CONFIG"
echo

if diff -u "$BACKUP_FILE" "$KERNEL_CONFIG"; then
    echo "Keine Ãnderungen an der Kernel-Konfiguration."
else
    echo "Die Kernel-Konfiguration enthÃ¤lt Ãnderungen."
fi

echo
echo "Kernel-Version:"
make -s kernelrelease

yes_no_prompt "Soll der Kernel jetzt kompiliert werden?" ||
    abort "Kernel-Build vom Benutzer abgebrochen."

# ============================================================
# Nitrokey Initramfs vorbereiten
# ============================================================

echo
echo "============================================================"
echo " Nitrokey Initramfs vorbereiten"
echo "============================================================"

"$NITROKEY_SCRIPT"

# ============================================================
# Kernel und Initramfs kompilieren
# ============================================================

echo
echo "============================================================"
echo " Genkernel Build"
echo "============================================================"

genkernel all

# ============================================================
# Abschluss
# ============================================================

echo
echo "============================================================"
echo " Kernel-Update erfolgreich abgeschlossen!"
echo "============================================================"
echo
echo "Kernel-Version: $(make -s kernelrelease)"
echo "Konfigurations-Backup: $BACKUP_FILE"
echo
echo "Bitte Kernel, Initramfs und Secure-Boot-Signaturen prÃ¼fen,"
echo "bevor du das System neu startest."

