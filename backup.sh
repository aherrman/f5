backupSuffix=`date +%Y%m%d_%H%M%S`
backupPath=/tmp/bigip.conf_$backupSuffix

echo Saving current configuration

# Need to make sure the current running config is flushed to the config file
# before backing it up.
b save

echo Backing up bigip.conf to $backupPath
cp -f /config/bigip.conf $backupPath

echo Backup complete.  To restore, call the following:
echo restoreBackup.sh $backupPath
