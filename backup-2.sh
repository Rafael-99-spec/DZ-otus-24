#!/usr/bin/env bash
export BORG_REMOTE_PATH=/usr/local/bin/borg1/borg1
export BORG_PASSCOMMAND="cat $HOME/.borg-passphrase"
export BORG_REPO='3205@usw-s003.rsync.net:kbfs_backup'

# borg create ... ::<snapshot-name> <backup-source>
borg create --progress --files-cache=ctime,size --noatime --noctime --nobsdflags ::kbfs-$(date +%s) /keybase/private/yoonsikp/

borg prune --keep-daily 7 --keep-weekly 8 --keep-monthly 12 --keep-yearly 15
