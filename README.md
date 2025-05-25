# Get-AURolesAndMembers

### How To Run
```
.\Get-AURolesAndMembers.ps1
```

### Output
```
=============================
Role Name      : Directory Readers
Role Desc      : Can read basic directory information. Commonly used to grant directory read access to applications and guests.
Scope          : / (Tenant-wide)
AU Name        : Not scoped to an AU
AU Id          : N/A
=============================

--- No members in AU ---


=============================
Role Name      : User Administrator
Role Desc      : Can manage all aspects of users and groups, including resetting passwords for limited admins.
Scope          : /administrativeUnits/4a3288aa-1a8b-485a-8ced-2bd80feef625
AU Name        : ONBOARDING-ENGINEERING
AU Id          : 4a3288aa-1a8b-485a-8ced-2bd80feef625
=============================

--- Members of ONBOARDING-ENGINEERING AU [4a3288aa-1a8b-485a-8ced-2bd80feef625] ---

User: Felix Schneider | UPN/Info: Felix.Schneider@megabigtech.com | Job Title: Engineer | Enabled: True
```

### Help
```
PS C:\mcrtp_bootcamp_tools> .\Get-AURolesAndMembers.ps1 -Help
Usage: Get-AURolesAndMembers.ps1 [-Output <file.txt|file.csv>] [-UserId <GUID>] [-Help|-h]

Options:
  -Output   Path to save output file (.txt or .csv). If omitted, output prints to console.
  -UserId   Optional. Specify a User ID to retrieve roles for another user.
           The Microsoft Graph access token contains your user ID in the 'oid' field.
  -Help, -h Show this help message.

Examples:
  .\Get-AURolesAndMembers.ps1 -Output AUReport.txt
  .\Get-AURolesAndMembers.ps1 -UserId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```
