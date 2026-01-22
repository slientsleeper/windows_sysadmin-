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

  function Ensure-Feature {
     param([string]$name)
     $f = get-windowsfeature -name $name -erroraction sto.\.git
     if (-not $f.Installed) {
        Install-WindowsFeature -name $name -IncludeManagementTools -erroraction stop | Out-Null
     }
  }# end of ensure function

  function New-OrgGetFolder {
    param([string]$path)
    if (-not (Test-Path -Path $path)) {
        New-Item -Path $path -ItemType Directory -ErrorAction Stop | Out-Null
    }
  }# end of get folder function

  function Set-BackupNTFSPerms{
    param(
      [string]$path,
      [string]$domainNeBios,
      [string]$computerAccount
    )

    # remove inheritance and set explicit perms
    & icacls $path /inheritance:r | Out-Null

    # domain admins full, computer modify system full
    & icacls $path /grant "$domainNeBios\Domain Admins:(OI)(CI)F" | Out-Null
    & icacls $path /grant "$domainNeBios\computerAccount:(OI)(CI)M" | Out-Null
    & icacls $path /grant  "SYSTEM:(OI)(CI)F" | Out-Null
  }# end of set backup ntfs  


  function Ensure-Smbshare{
    param(
      [string] $name,
      [string] $path,
      [string] $domainNeBios,
      [string] $computerAccount
    )

    $existing = Get-SmbShare -Name $name -ErrorAction SilentlyContinue
    if ($existing){
      write-host " smb share $name already exists skipping creating"
      return
    }# end of if statement

    New-SmbShare -name $name -path $path -FullAccess "$domainNeBios\Domain Admins","$domainNeBios\$computerAccount" -ErrorAction Stop | Out-Null
  }#  end of smbshare function

   function Enable-FileSharingfirewall{
    # enable file and printer sharing firewall rule
    Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing" -ErrorAction Stop | Out-Null
   }