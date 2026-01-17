# windows file server + dfs namespae

## Goal 
build a windows file server in a domain environment with:
- ntfs permissions via ad security groups 
- smb share ( hidden optional $)
- domain-based dfs namespace for stable paths
- optional gpo drive mapping
- shadow copies + backups
- auditing for file access and deltes 

## Environment
- domain: name of domain
- Domain Controler: full domain name 
- File server: name of file server
- Data volumne: d:\
- Share folder: name of shared folder or folders 
- smb share: name of smb share 
- dfs name space: \\domain\shares\share_folder_name
- dfs target: \\domainname\share_folder_name hidden add $


## Architecture (mental model)

user  -> gpo drive map -> dfs path 

key rules:
- dfs does not store data. dfs points to the smb shares
- share permissions are permissve; ntfs enforces access
- gpo makes the drive visible; it does not grant permissions

## Build Summary
1. Provision and domain-join to file server 
2. create the folder structure on data disk (D:\shares\name_of_share)
3. apply ntfs acls:
    - system: full
    - administrators: full
4. create smb share:
    - name_of_share - > D:\shares\name_of_share
    - share permissions: authenticated users full
5. install dfs namespace role
6. create domain-based-namespace:
    - \\fileserver\path_to_folder
7. create dfs folder + target
-   \\fileserver\path_to_folder -> \\domain\path_to_share
8.  enable auditiing:
- advanced audit policy: audit file system
    - folder sacl for write-delete
9. enable shadow copies on D: (basic schedule)

## Validation
- Create file via DFS:
  - New-Item "\\code.local\Shares\Staff\dfs_test.txt" -ItemType File
- Confirm file appears in D:\Shares\Staff
- Confirm security events show delete/write activity (4663 / 4660)

## Troubleshooting Highlights
- “RPC server unavailable” when creating domain-based DFS was caused by corrupted AD DFS metadata (nested CN object).
- Fix: Remove the broken DFS namespace object from AD (ADSI Edit under CN=System → CN=Dfs-Configuration), then recreate.

## How to Run Automation
See: scripts/Build-FileServerDfs.ps1