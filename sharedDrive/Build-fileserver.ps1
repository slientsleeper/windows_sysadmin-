 <#
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

#>
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)][string]$SDomainFqdn, #fqdn of domain
    [parameter(Mandatory=$true)][string]$SNetBios, #code name of domain example code.local
    [parameter(Mandatory=$true)][string]$SFileServer, #name of file server
    [parameter(Mandatory=$true)][string]$NamespaceName, #shares
    [parameter(Mandatory=$true)][string]$DfsFolderName, #name of folder
    [parameter(Mandatory=$true)][string]$ShareName, #sharename
    [parameter(Mandatory=$true)][string]$DataPath, #path to folder
    [parameter(Mandatory=$true)][string]$AdGroup, #adgroup for ntfs permissions
    [switch]$EnableShawdowCopies, #hidden share
    [swutch]$EnableAuditing #hidden share
)
##--
#example 
# .\Build-fileserver.ps1 -SDomainFqdn "contoso.local" -SNetBios "CONTOSO" -SFileServer "FS1" -NamespaceName "SharedData" -DfsFolderName "Projects" -ShareName "Projects$" -DataPath "D:\Shares\Projects" -AdGroup "Contoso\Domain Users" -EnableShawdowCopies -EnableAuditing


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
icacls $DataPath /grant "$NetBIOS\$AdGroup:(OI)(CI)M" | Out-Null

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

get-smbshare -name $ShareName 
get-smbshareaccess -name $ShareName

# --
# dfs namespace role 
# --

log " ensuring dfs namespace role is inherited"

if(-not(Get-WindowsFeature -Name FS-DFS-Namespace).Installed) {
    log " installing dfs namespace role"
    Install-WindowsFeature -Name FS-DFS-Namespace | out-null
} else {
    log " dfs namespace role already installed"
}

start-service dfs -ErrorAction SilentlyContinue

# ---------------------------
# DFS Namespace
# ---------------------------
$DfsRoot = "\\$DomainFqdn\$NamespaceName"

Log "Creating DFS Namespace: $DfsRoot"

if (-not (Get-DfsnRoot -ErrorAction SilentlyContinue | Where-Object Path -eq $DfsRoot)) {
  New-DfsnRoot `
    -Path $DfsRoot `
    -TargetPath "\\$FileServer\$NamespaceName" `
    -Type DomainV2 | Out-Null
}


# --
# dfs folder target
# --

$dfsFolderPath = "$dfsroot\$DfsFolderName"
$dfstarget  = "\\$SFileServer\$ShareName"
log "creating dfs folder: $dfsFolderPath with target $dfstarget"

if(-not(Get-DfsnFolder -Path $dfsFolderPath -ErrorAction SilentlyContinue)) {
    New-DfsnFolder -Path $dfsFolderPath -TargetPath $dfstarget | out-null
} else {
    log "dfs folder $dfsFolderPath already exists"
}

get-dfsnfolder -path $dfsFolderPath

# -- 
# auditing
# --
if($EnableAuditing) {
    log "enabling file system auditing on $DataPath"

    # enable auditing via gpo
    auditpol /set /subcategory:"File System" /success:enable /failure:enable | out-null

    # set auditing on folder
    $acl = Get-Acl $DataPath
    $auditRule = New-Object System.Security.AccessControl.FileSystemAuditRule("EVERYONE","FullControl","ContainerInherit,ObjectInherit","None","Success,Failure")
    $acl.AddAuditRule($auditRule)
    Set-Acl -Path $DataPath -AclObject $acl

    log "file system auditing enabled on $DataPath"
}


# --
# shadow copies 
# --
if ($EnableShawdowCopies) {
    log "enabling shadow copies on $DataPath"
    vssadmin add shadowstorage /for=D: /on=D: /maxsize=10% | out-null
    vssadmin list shadowstorage | out-null
    log "shadow copies enabled on $DataPath"
}# end of enable shadow copies

# --
# final validation
#
log "build complete"
log "dfs folder: $dfsFolderPath"
