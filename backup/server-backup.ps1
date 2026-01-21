<#
.synoopsis
 backup lab automation: configure server to backup as target and sbackup server to it 

 .Description
    configures:
        - formats/labels backup disk (optional)
        - creates d:\backups\servertobackup
        - set ntfs permissions
        - creates smb share (hidden) \\backupserver\servertobackup

    mode servertovackup:
        - installs windows backup feature
        - tests smb connectivity
        - runs full (allcritical) backup and/or system state backup
        - verifies backup versions 

.notes
  run powershell as admin
#>

  [CmdletBinding()]
  param(
    [string]$mode,
    # common
    [string] $doomainNeBios,
    [string] $domainFQDN,
    # backup server settings
    [string] $backupDriverLetter = "D",
    [string] $backupRoot, # D:\serverbackup
    [string] $backupFolder, #backup folder name of server to backup

    [string] $shareName, # share name of backup folder
    # source server (dc) computer account (change if your dc isnt dc01)
    [string] $SourceComputerAccount, # domainserver aaccount example alpha$

    # server to backup settings
    [string] $backupServerName,
    [string] $backupType # [ValidateSet("Full","SystemState","Both")]
  )

  function Require-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Error "This script must be run as an Administrator."
        exit 1
    }
  }