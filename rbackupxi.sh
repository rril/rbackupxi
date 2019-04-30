#!/bin/bash
for block in "$@"
do
	VNAM=$( echo $block | awk -F "=" '{print $1}' | sed -e 's/^ *//g' -e 's/ *$//g' )
	VNAM=${VNAM//-/}
	VVAL="$( echo $block | awk -F "=" '{print $2}' | sed -e 's/^ *//g' -e 's/ *$//g' )"
	#VVAL=${VVAL//"/\"}
	eval $VNAM="\"$VVAL\""
done

excludevm=${excludevm/ /\|}

if [ -z "$hostip" ]
then
       	echo "host-ip parameter DOES NOT set."
	exit 1
fi

if [ -z "$backuppoint" ]
then
       	echo "backup-point parameter DOES NOT set."
	exit 1
fi

if [ -z "`ssh "$hostip" \"[ -d $backuppoint ] && echo exists\"`" ]
then
       	echo "Directory $backuppoint DOES NOT exists."
	exit 1
fi



if [ ! -z "$excludevm" ]
then
	excludevm=${excludevm//,/|}
	HOSTS_ID=`ssh "$hostip" vim-cmd vmsvc/getallvms | grep -Evi "vmid|$excludevm" | gawk '{print $1}' `
else
	HOSTS_ID=`ssh "$hostip" vim-cmd vmsvc/getallvms | grep -vi "vmid" | gawk '{print $1}' `
fi

for HID in $HOSTS_ID
do
	echo -n "||"
	if [ "Powered on" = "`ssh "$hostip" vim-cmd vmsvc/power.getstate $HID | grep 'Powered on'`" ]
	then
		HOSTS_POWERON="$HOSTS_POWERON $HID"

	fi
done
echo ""

for HID in $HOSTS_POWERON
do
	echo "host $HID: "
	DATASTORE_HOST=$(ssh "$hostip" vim-cmd vmsvc/get.datastores 14| grep url | awk '{print $2}')
	LS=`ssh "$hostip" ls -l $(ssh "$hostip" vim-cmd vmsvc/get.datastores 14| grep url | awk '{print $2}')/.. | grep  $(ssh "$hostip" vim-cmd vmsvc/get.datastores 14| grep url | awk -F / '{print $NF}') | awk '{printf "%s""|",$9}' | awk '{print substr($0,1,length($0)-1)}'`
	DATASTORE_HOST_FS=$(ssh "$hostip" df | grep -E "$LS" | awk '{print $4}')
	FILES_HOST_RAW=$(ssh "$hostip" vim-cmd vmsvc/get.filelayoutex $HID | grep name | awk -F = '{print $2}')
	FILES_HOST=$(echo "$FILES_HOST_RAW" | awk '{print $2}'| cut -d'"' -f1)
	VMX_HOST=$(echo "$FILES_HOST" | grep -E "\.vmx$")
	VMDK_HOST=$(echo "$FILES_HOST" | grep -E "\.vmdk$")
	VMDK_HOST_FS=$(ssh "$hostip" "cd $DATASTORE_HOST ; ls -l `echo $VMDK_HOST` 2> /dev/null" | awk '{sum += $5} END {print sum}')
	if [ "$VMDK_HOST_FS" -gt "$DATASTORE_HOST_FS" ]
	then
		echo Snepshot Error $HID echo vmdk to bigger
		exit 1
	else
		HOST_TARGET_BK="$backuppoint/$(ssh "$hostip" grep displayName $DATASTORE_HOST/$VMX_HOST |awk '{print substr($NF,2,length($NF)-2)}')"
		echo copy VMX file to $HOST_TARGET_BK
		ssh "$hostip" "rm -r \"$HOST_TARGET_BK-1\" && mv \"$HOST_TARGET_BK\" \"$HOST_TARGET_BK-1\""
		ssh "$hostip" "mkdir \"$HOST_TARGET_BK\" && cp \"$DATASTORE_HOST/$VMX_HOST\" \"$HOST_TARGET_BK/\""

		echo Take snapshot
		ssh "$hostip" "vim-cmd vmsvc/snapshot.create $HID rbackup \"create by rbackup script for make clone to backup\" 0 0"
		ssh "$hostip" "vim-cmd vmsvc/snapshot.get $HID"
		ssh "$hostip" "cd \"$DATASTORE_HOST/\" && cp `echo $VMDK_HOST` \"$HOST_TARGET_BK/\""

		echo Remove all snapshots
		ssh "$hostip" "vim-cmd vmsvc/snapshot.removeall $HID"
		ssh "$hostip" "vim-cmd vmsvc/snapshot.get $HID"

		echo -n Complete in 
		date
	fi
done
