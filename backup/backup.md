# Windows server backup lab

## Goal
Build a dedicated backup server (bk01) to store backups from a domain controller (domain controler) and valiate recovery concepts

- Remote backup storage seperation
- System state vs full (All critical volumnes) backups
- none-authopritative restores ( therory + lab readiness)
- monitoring and vertification 

## Environment
- Domain: domain name
- DC: domain name 
- Backup Server: server 
- Backup Target:smb sahre on the server 

## Architecture 
Domain controller creates backups and writes them to a secure share on the backupserver
\\domain\backups

## what i buult (summary)
1. provision backup and join it to doamin
2. Attached and formatted dedicated backup disk to backup server 
3. Created D:\backups\servertoback
4. applied least ntfs permissions:
    - domain admins: full
    - domain(computer account):modify
    - system: fiull
5. created smb share: \\backups\servertobackup
6. installed windows server backup feature on server to backup
7. tested connectivity to smb (tcp/4455)
8. Run backups:
     - full: wbadmin start backup -allcritical 
     - Systems state: wbadmin start systemstatebackup
 9. Verified backups:
    - wbadmin get versions
    - confirmed windowsimage folder on backup server 

## command used(key)

### install wsb on server to backup
install windowsfeature windows-server-backup -IncludeManagementTools '

### run full backup
wdbadmin start backup -backuptarget:\\backupserver\server_to_backup-backups

### verify backups
wbadmin get versions -backuTarget:\\backupserver\server_to_backups-backups

## Notes / lessons learned 
- do not back up a dc to itself; backups must servive a dc failure
- system state is for ad/dns/sysvol recovery; full backups support bare-metal recovery 
- monitoring matters; a backup with no alerting is effectively untrusted 

## next enhancements 
- add file server + dfs and test restore behavior 
- add event-log based alering for backup failures 
- compare native wsb

