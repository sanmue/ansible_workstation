#!/bin/bash

# Set PPA Priority for Mozillateam and block Firefox from Ubuntu’s own repository
# Quelle: https://fostips.com/ubuntu-21-10-two-firefox-remove-snap/#rb-Step-2-Install-back-the-classic-Firefox-Deb-package
#
# # Anmerkung: wird aktuell nicht benötigt, da aktuell als flatpak installiert wird
dir="/etc/apt/preferences.d"
mozfile="99mozillateamppa"

touch "${dir}/${mozfile}"

cat > "${dir}/${mozfile}" << EOF
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 501

Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1

EOF

