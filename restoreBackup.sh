#!/bin/bash

if [ $# != 1 ]; then
  echo "Usage: $0 <backupFile>"
  echo "    backupFile - The file containing the backup to restore"
  exit 1
fi

backupPath=$1

if [ ! -f $backupPath ]; then
  echo No backup file found at $backupPath
fi

cp $backupPath /config/bigip.conf
b load
retCode=$?
if [ $retCode != 0 ]; then
  echo Error loading backup, restoring config file to current running config
  b save
fi
echo Done.
