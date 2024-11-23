#!/usr/bin/env bash

if [ ! "$(ls "${HOME}/pCloud-Mnt")" ]; then
    mkdir -p "${HOME}/pCloud-Mnt"
fi

echo "Mounting pcloud to '${HOME}/pCloud-Mnt'"
echo "Leave terminal window/session open as long as mount is required."
echo "To stop / unmount: press <CTRL>+<C> or close terminal window/session."

rclone --vfs-cache-mode writes mount pcloud: "${HOME}/pCloud-Mnt"
