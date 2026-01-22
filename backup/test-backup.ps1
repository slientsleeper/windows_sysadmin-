# test the backup 

param(
    [string] $backupServerName,
    [string] $sharename
)

$targetUNC = "\\$backupServerName\$sharename"

write-host "testing smb 445 "
Test-Connection $backupservername -port 445 

write-host "listing backup share ...."
dir $targetUNC

write-host "checking backup versions"
wbadmin get versions