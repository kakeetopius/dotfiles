#!/usr/bin/env bash

REMOTE_NAME="Strath Onedrive:"
LOCAL_DIR="/home/pius/Strath Onedrive/"
rclone_options1="--progress --verbose"
rclone_options2="--progress --verbose --resync"

rclone bisync $rclone_options1 "$REMOTE_NAME" "$LOCAL_DIR"

if [ "$?" -eq "7" ]; then
    echo "Resyncing.................."
    rclone bisync $rclone_options2 "$REMOTE_NAME" "$LOCAL_DIR"
    echo "Trying to sync again........"
    rclone bisync $rclone_options1 "$REMOTE_NAME" "$LOCAL_DIR"
fi

echo "Rclone exited with code $?"
