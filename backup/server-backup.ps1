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
   }# end of enable firewall function

   function Test-SmbFromDC{
    param(
    [string]$servername,
    [string]$shareName
    )
    write-host "testing tcp/445 to $servername"
    $tnc = test-connection -ComputerName $servername -Port 445
    if (-not $tnc){
      throw "tcp/445 test connection to $servername failed"
    }# end of if statement
    $path = "\\$servername\$shareName"
    Write-Host "testing smb access to $path"
    try]

    {
      $items = Get-ChildItem -Path $path -ErrorAction Stop
      Write-Host "smb access to $path succeeded"
    }
    catch{
      throw "smb access to $path failed: $_"
    }
   }# end of function test smb from d 

function Run-Backup {
  param(
  [string] $backupTargetUnc,
  [ValidateSet("Full","SystemState","Both")]
  [string] $type
  )
  if ($type -eq "Full" -or $type -eq "Both"){
    Write-Host "running full backup to $backupTargetUnc"
    wbadmin start backup -backupTarget:$backupTargetUnc -allcritical -quiet -erroraction stop
  }# end of if statement

  if ($type -eq "SystemState" -or $type -eq "Both"){
    Write-Host "running system state backup to $backupTargetUnc"
    wbadmin start systemstatebackup -backupTarget:$backupTargetUnc -quiet -erroraction stop
  }# end of if statement
}# rnf of run backup function

function Verify-Backup{
  param(
    [string] $backupTargetUnc
  )
  write-host " checking backup versions on $BackupTargetUnc"
  & wbadmin start systemstatebackup -backupTarget:$backupTargetUnc -quiet
}# end of verify backup function
Require-Admin

if($mode -eq "backupserver"){
  write-host " === mode : backupserver (configure backup tagret) ==="

  # ensure smb share is allowed on host firewall 
  Enable-FileSharingfirewall

  $backupRootPath = "$($backupDriverLetter):\backups"
  $backupFolderPath = join-path $backupRootPath $backupFolder

  New-OrgGetFolder -path $backupRootPath
  New-OrgGetFolder -path $backupFolderPath

  Set-BackupNTFSPerms -path $backupFolderPath -domainNeBios $doomainNeBios -computerAccount $SourceComputerAccount

  Ensure-Smbshare -name $shareName -path $backupFolderPath -domainNeBios $doomainNeBios -computerAccount $SourceComputerAccount

  write-host "Backup target ready:"
  write-host " Folder: $backupFolderPath" 
  write-host " Share: \\$backupServerName\$shareName"
  Write-Host " next: run this script on domain in mode=domain to install wsb and run backups"
  exit0  
}# end of backup server

if($mode -eq "alpha"){
  write-host "== MODE: domain ( install wsb + run backups) ==="
  Ensure-Feature -name "windows server backup "

  $targetUnc = "\\$backupServerName\$shareName"

  Test-SmbFromDC -servername $backupServerName -shareName $shareName
  Run-Backup -backupTargetUnc $targetUnc -type $backupType
  Verify-Backup -backupTargetUnc $targetUnc

  write-host "done"
  exit 0

}