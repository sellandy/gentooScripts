#!/bin/bash

# Aktivieren des Alias
shopt -s expand_aliases
source /etc/bash/bashrc.d/nitrogenkernel.sh

# Funktion zum Überprüfen der Benutzerantwort
yes_no_prompt() {
    while true; do
        read -rp "$1 (ja/nein): " response
        case "$response" in
            [Jj]*) return 0;;
            [Nn]*) return 1;;
            *) echo "Bitte mit 'ja' oder 'nein' antworten.";;
        esac
    done
}

# Sicherstellen, dass das System up-to-date ist
yes_no_prompt "Ist dein System up-to-date?" || { echo "Bitte das System zuerst aktualisieren!"; exit 1; }

echo "Starte Kernel-Update-Prozess..."

# Überprüfen, ob /boot eingehängt ist und ggf. aushängen
if mount | grep -q 'on /boot '; then
    echo "/boot ist eingehängt, versuche es auszuhängen..."
    umount /boot || { echo "Fehler beim Aushängen von /boot!"; exit 1; }
else
    echo "/boot ist nicht eingehängt."
fi

# Backup der aktuellen Kernel-Konfiguration
echo "Erstelle Backup der aktuellen Kernel-Konfiguration..."
mkdir -p /usr/src/.kernel_config_backups/
cp /usr/src/linux/.config /usr/src/.kernel_config_backups/kernel_config_$(uname -r)_$(date +"%Y-%m-%d_%T")

echo "Wechsle in das Kernel-Verzeichnis..."
cd /usr/src/linux || { echo "Fehler: Verzeichnis /usr/src/linux nicht gefunden!"; exit 1; }

# Bereinigung des Build-Verzeichnisses
echo "Führe 'make clean' aus..."
make clean

# Kernel-Version auswählen
echo "Wähle die gewünschte Kernel-Version mit 'eselect kernel' aus:"
eselect kernel list
echo "Bitte die entsprechende Nummer eingeben: "
read -r kernel_version
echo "Setze den Kernel-Symlink..."
eselect kernel set "$kernel_version"

# Zurückkopieren der letzten gesicherten Konfiguration
echo "Stelle die letzte gesicherte Kernel-Konfiguration wieder her..."
latest_backup=$(ls -t /usr/src/.kernel_config_backups/kernel_config_* | head -n 1)
if [ -f "$latest_backup" ]; then
    cp "$latest_backup" /usr/src/linux/.config
    echo "Konfigurationsdatei $latest_backup wurde wiederhergestellt."
else
    echo "Keine vorherige Kernel-Konfiguration gefunden!"
fi

# Erstellen der neuen Konfiguration basierend auf der alten
echo "Führe 'make olddefconfig' aus..."
make olddefconfig

# Vergleichen der alten und neuen Konfiguration
echo "Vergleiche die alte und neue Kernel-Konfiguration..."
diff "$latest_backup" /usr/src/linux/.config || echo "Es gibt Änderungen in der Konfiguration."

# Kernel mit nitrogenkernel kompilieren
echo "Starte die Kernel-Kompilierung mit 'nitrogenkernel'..."
nitrogenkernel

echo "Kernel-Update abgeschlossen!"

