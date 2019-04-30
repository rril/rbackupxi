## RbackupXI

This script run only on remote server.
Keeps backups up to two copies of each server it is backing up
Backing up servers running only the actual

--exclude-vm    Exclude vms in regex syntex or comma separated (,) list of servers.
--backup-point  Full  path with datastore for backup point on ESXi server. (recomended NFS or other remote FS.)
--host-ip       Host IP (or dns) for remote connection

Syntex: rbackup.sh --exclude-vm="$EXCLSRV" --backup-point=$BACKUP_PATH_ON_SERVER --host-ip=$HOST_IP

Example:
```
#!/bin/bash
HOST_IP=$1
TEST=false
EXCLSRV="server-231,Orouter-146,win-serv1,mysql1"
BACKUP_PATH_ON_SERVER=/vmfs/volumes/backup/servers/

cd /mnt/backups/
HOST_NAME="${HOST_IP//[!0-9a-Z]/_}"
./rbackup.sh --exclude-vm="$EXCLSRV" --backup-point=$BACKUP_PATH_ON_SERVER --host-ip=$HOST_IP  > ./access.$HOST_NAME.log 2>./error.$HOST_NAME.log &

```
