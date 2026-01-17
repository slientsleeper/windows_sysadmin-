 .synoopsis
 automated windows file server + dfs namespace build

 .description
 creates:
    - ntfs folder structure
    - ntfs permissions using adgroup
    - smb share (hidden optional)
    - dfs folder + target
    - dfs namespace (if not existing)file system auditing
    - shadow copies

.notes
run ad domain admin on the server hosting dfs 

[CmdletBinding()]
param(
    [parameter(Mandatory=$true)][string]$SDomainFqdn, #fqdn of domain
    [parameter(Mandatory=$true)][string]$SNetBios, #code
    [parameter(Mandatory=$true)][string]$SFileServer, #name of file server
    [parameter(Mandatory=$true)][string]$nNamespaceName, #shares
    [parameter(Mandatory=$true)][string]$DfsFolderName, #name of folder
    [parameter(Mandatory=$true)][string]$ShareName, #sharename
    [parameter(Mandatory=$true)][string]$DataPath, #path to folder
    [parameter(Mandatory=$true)][string]$AdGroup, #adgroup for ntfs permissions
    [switch]$EnableShawdowCopies, #hidden share
    [swutch]$EnableAuditing #hidden share
)

$errorActionPreference = "Stop"

function log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $message"
}

# --
# sanity checks
# --
log "running as $(whoami)"
if (-not (test-path $DataPath)) {
    log "creating data folder: $Ddatapath"
    new-item -path $DataPath -itemtype directory | out-null
}

# --
# ntfs permissions
#
log "setting ntfs permissions"

icacls $DataPath /inheritance:d | out-null
icacls $DataPath /grant: "SYSTEM:(OI)(CI)F" | out-null
icacls $DataPath /grant: "BULTIN\Administrators:(OI)(CI)F" | out-null
icacls $DataPath /grant: "$NetBIOS\$AdGroup:(OI)(CI)M" | out-null

icacls $DataPath 

# --
# smb share 
# 
log "creating smb share: $ShareName"

if(-not(Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name $ShareName -Path $DataPath -FullAccess "Authenticated Users" | out-null
} else {
    log "smb share $ShareName already exists"
}
