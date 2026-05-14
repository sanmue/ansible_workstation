#!/usr/bin/env bash

if [ ! "$(ls "${HOME}/pCloud-Mnt")" ]; then
    echo -e "\e[1;33mPfad '${HOME}/mnt/pCloud-Mnt' noch nicht vorhanden, wird erstellt...\e[0m"
    mkdir -pv "${HOME}/mnt/pCloud-Mnt"
fi

echo -e "\nMounting pcloud to '${HOME}/mnt/pCloud-Mnt'"
echo "Leave terminal window / session open as long as mount is required."
echo -e "To stop / unmount: press <CTRL>+<C> or close terminal window / session.\n"

rclone --vfs-cache-mode writes mount pcloud: "${HOME}/mnt/pCloud-Mnt"
