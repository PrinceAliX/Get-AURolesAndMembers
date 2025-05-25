<#
.SYNOPSIS
    Retrieves role assignments for the current or specified user including AU scoped roles and lists AU members.

.PARAMETER Output
    Optional. Path to save output. Supports .txt or .csv.
    If not specified, output is printed to console only.

.PARAMETER UserId
    Optional. Specify a User ID (ObjectId) to retrieve roles for a different user.
    The Microsoft Graph access token contains your user ID in the oid field.

.PARAMETER Help
    Show this help message.

.EXAMPLE
    .\Get-AURolesAndMembers.ps1 -Output report.txt

.EXAMPLE
    .\Get-AURolesAndMembers.ps1 -UserId "<user-object-id>"

.EXAMPLE
    .\Get-AURolesAndMembers.ps1 -h
#>

param(
    [string]$Output,
    [string]$UserId,
    [switch]$Help,
    [switch]$h
)

function Show-Help {
    Write-Host @"
Usage: Get-AURolesAndMembers.ps1 [-Output <file.txt|file.csv>] [-UserId <GUID>] [-Help|-h]

Options:
  -Output   Path to save output file (.txt or .csv). If omitted, output prints to console.
  -UserId   Optional. Specify a User ID to retrieve roles for another user.
           The Microsoft Graph access token contains your user ID in the 'oid' field.
  -Help, -h Show this help message.

Examples:
  .\Get-AURolesAndMembers.ps1 -Output AUReport.txt
  .\Get-AURolesAndMembers.ps1 -UserId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
"@
}

if ($Help -or $h) {
    Show-Help
    exit 0
}

# Validate Output extension if provided
if ($Output) {
    $ext = [System.IO.Path]::GetExtension($Output).ToLower()
    if ($ext -ne ".txt" -and $ext -ne ".csv") {
        Write-Error "Output file must have extension .txt or .csv"
        exit 1
    }
}

# Connect Microsoft Graph if not connected
if (-not (Get-MgContext)) {
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "RoleManagement.Read.Directory", "Directory.Read.All"
}

$outputData = @()

# Get user ID
if (-not $UserId) {
    $UserId = (Get-MgUser -UserId (Get-MgContext).Account).Id
}

$assignments = Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$UserId'"

foreach ($assignment in $assignments) {
    $role = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $assignment.RoleDefinitionId
    $directoryScope = $assignment.DirectoryScopeId
    $auId = $directoryScope -replace "^/administrativeUnits/", ""

    $auName = "N/A"
    $scopeDesc = "Unknown"
    $membersList = @()

    if ($directoryScope -eq "/") {
        $scopeDesc = "/ (Tenant-wide)"
        $auName = "Not scoped to an AU"
        $auIdOut = "N/A"
    }
    elseif ($directoryScope -like "/administrativeUnits/*") {
        try {
            $au = Get-MgDirectoryAdministrativeUnit -AdministrativeUnitId $auId
            $scopeDesc = $directoryScope
            $auName = $au.DisplayName
            $auIdOut = $au.Id

            # Get members
            $members = Get-MgDirectoryAdministrativeUnitMember -AdministrativeUnitId $au.Id
            foreach ($member in $members) {
                $type = $member.AdditionalProperties['@odata.type']
                switch ($type) {
                    "#microsoft.graph.user" {
                        $u = Get-MgUser -UserId $member.Id -Property "DisplayName,UserPrincipalName,UserType,JobTitle,AccountEnabled"
                        $membersList += [PSCustomObject]@{
                            MemberType = "User"
                            Name       = $u.DisplayName
                            UPN        = $u.UserPrincipalName
                            UserType   = $u.UserType
                            JobTitle   = $u.JobTitle
                            Enabled    = $u.AccountEnabled
                        }
                    }
                    "#microsoft.graph.group" {
                        $g = Get-MgGroup -GroupId $member.Id -Property "DisplayName,Mail"
                        $membersList += [PSCustomObject]@{
                            MemberType = "Group"
                            Name       = $g.DisplayName
                            UPN        = $g.Mail
                            UserType   = ""
                            JobTitle   = ""
                            Enabled    = ""
                        }
                    }
                    "#microsoft.graph.device" {
                        $d = Get-MgDevice -DeviceId $member.Id -Property "DisplayName,OperatingSystem,DeviceId"
                        $membersList += [PSCustomObject]@{
                            MemberType = "Device"
                            Name       = $d.DisplayName
                            UPN        = $d.OperatingSystem
                            UserType   = ""
                            JobTitle   = ""
                            Enabled    = ""
                        }
                    }
                    default {
                        $membersList += [PSCustomObject]@{
                            MemberType = "Other"
                            Name       = $member.Id
                            UPN        = ""
                            UserType   = ""
                            JobTitle   = ""
                            Enabled    = ""
                        }
                    }
                }
            }
        }
        catch {
            $scopeDesc = $directoryScope
            $auName = "[Failed to retrieve AU]"
            $auIdOut = $auId
        }
    }
    else {
        $scopeDesc = $directoryScope
        $auName = "Unknown scope"
        $auIdOut = $auId
    }

    # Collect role info and scope
    $roleEntry = [PSCustomObject]@{
        RoleName     = $role.DisplayName
        RoleDesc     = $role.Description
        Scope        = $scopeDesc
        AUName       = $auName
        AUId         = $auIdOut
        Members      = $membersList
    }

    $outputData += $roleEntry
}

# Output logic
if (-not $Output) {
    foreach ($roleEntry in $outputData) {
        Write-Host "============================="
        Write-Host "Role Name      : $($roleEntry.RoleName)"
        Write-Host "Role Desc      : $($roleEntry.RoleDesc)"
        Write-Host "Scope          : $($roleEntry.Scope)"
        Write-Host "AU Name        : $($roleEntry.AUName)"
        Write-Host "AU Id          : $($roleEntry.AUId)"
        Write-Host "============================="

        if ($roleEntry.Members.Count -eq 0) {
            Write-Host "`n--- No members in AU ---`n"
        }
        else {
            Write-Host "`n--- Members of $($roleEntry.AUName) AU [$($roleEntry.AUId)] ---`n"
            foreach ($m in $roleEntry.Members) {
                Write-Host "$($m.MemberType): $($m.Name) | UPN/Info: $($m.UPN) | Job Title: $($m.JobTitle) | Enabled: $($m.Enabled)"
            }
        }
        Write-Host ""
    }
}
else {
    $ext = [System.IO.Path]::GetExtension($Output).ToLower()
    if ($ext -eq ".txt") {
        $txtOutput = ""

        foreach ($roleEntry in $outputData) {
            $txtOutput += "=============================`r`n"
            $txtOutput += "Role Name      : $($roleEntry.RoleName)`r`n"
            $txtOutput += "Role Desc      : $($roleEntry.RoleDesc)`r`n"
            $txtOutput += "Scope          : $($roleEntry.Scope)`r`n"
            $txtOutput += "AU Name        : $($roleEntry.AUName)`r`n"
            $txtOutput += "AU Id          : $($roleEntry.AUId)`r`n"
            $txtOutput += "=============================`r`n"

            if ($roleEntry.Members.Count -eq 0) {
                $txtOutput += "`r`n--- No members in AU ---`r`n"
            }
            else {
                $txtOutput += "`r`n--- Members of $($roleEntry.AUName) AU [$($roleEntry.AUId)] ---`r`n"
                foreach ($m in $roleEntry.Members) {
                    $txtOutput += "$($m.MemberType): $($m.Name) | UPN/Info: $($m.UPN) | Job Title: $($m.JobTitle) | Enabled: $($m.Enabled)`r`n"
                }
            }
            $txtOutput += "`r`n"
        }

        $txtOutput | Out-File -FilePath $Output -Encoding UTF8
        Write-Host "Output saved to $Output" -ForegroundColor Green
    }
    elseif ($ext -eq ".csv") {
        $csvOutput = @()
        foreach ($roleEntry in $outputData) {
            if ($roleEntry.Members.Count -eq 0) {
                $csvOutput += [PSCustomObject]@{
                    RoleName       = $roleEntry.RoleName
                    RoleDesc       = $roleEntry.RoleDesc
                    Scope          = $roleEntry.Scope
                    AUName         = $roleEntry.AUName
                    AUId           = $roleEntry.AUId
                    MemberType     = ""
                    MemberName     = ""
                    MemberUPN      = ""
                    MemberJobTitle = ""
                    MemberEnabled  = ""
                }
            }
            else {
                foreach ($m in $roleEntry.Members) {
                    $csvOutput += [PSCustomObject]@{
                        RoleName       = $roleEntry.RoleName
                        RoleDesc       = $roleEntry.RoleDesc
                        Scope          = $roleEntry.Scope
                        AUName         = $roleEntry.AUName
                        AUId           = $roleEntry.AUId
                        MemberType     = $m.MemberType
                        MemberName     = $m.Name
                        MemberUPN      = $m.UPN
                        MemberJobTitle = $m.JobTitle
                        MemberEnabled  = $m.Enabled
                    }
                }
            }
        }

        $csvOutput | Export-Csv -Path $Output -NoTypeInformation -Encoding UTF8
        Write-Host "Output saved to $Output" -ForegroundColor Green
    }
}
