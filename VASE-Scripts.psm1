<#
    .SYNOPSIS
    Adds user to VASE AD and adds new user to necessary groups.

    .DESCRIPTION
    Adds user to VASE Active Directory and adds the new user to necessary groups.  
    Details of current configuration in Notes section below.

    .PARAMETER FirstName
    First name of user to be added.

    .PARAMETER LastName
    Last name of user to be added.

    .PARAMETER Email
    RIT email of user to be added.  Must be in abc1234@g.rit.edu format.

    .PARAMETER AdditionalGroups
    A list of additional groups the user should be added to. Default groups in notes.

    .PARAMETER OverrideRITEmail
    Used to add a user without an RIT email.

    .EXAMPLE
    Add-VASEADUser -FirstName Joe -LastName Graham -Email jxg5678@g.rit.edu

    .NOTES
    Current Configuration:
    Primary Domain Controller: dc-2.vase.local
    General User OU: OU=Users,OU=CDT,DC=vase,DC=local
#>
function Add-ADUser {
    Param (
        [Parameter(Mandatory=$true)][string]$FirstName,
        [Parameter(Mandatory=$true)][string]$LastName,
        [Parameter(Mandatory=$true)][string]$Email,
        [Parameter(Mandatory=$true)][string[]]$Groups,
        [switch]$OverrideRITEmail
    )
    # Validate user input for Email is an RIT email
    # Added an option to override (just in case)
    try {
        New-Object -TypeName System.Net.Mail.MailAddress -ArgumentList $Email | Out-Null
    }
    catch {
        Write-Error "The email address entered is not in the form required for an e-mail address."
        return
    }

    # Temp var for string after the "@" in the address
    $EmailSuffix = $Email.Split("@")[1]

    # If the email address doesn't equal "g.rit.edu", then
    #   If the email address equals "rit.edu", convert to "g.rit.edu"
    #   Else check if $OverrideRITEmail is set to true
    if($EmailSuffix -ne "g.rit.edu") {
        if($EmailSuffix -eq "rit.edu") {
            Write-Host "Converting e-mail address to g.rit.edu" -ForegroundColor Yellow
            $Email = $Email.Split("@")[0] + "@g.rit.edu"
        }
        else {
            if($OverrideRITEmail) {
                Write-Warning -Message "You have overridden the RIT email check! Adding non-RIT account."
            }
            else {
                Write-Error "Non-RIT e-mail address entered.  Either enter an RIT e-mail address or override if necessary."
                return
            }
        }
    }

    # Get user's full name
    $FullName = $FirstName + " " + $LastName

    # Make username for the user
    $UserName = $FirstName[0] + $LastName

    # Add new user with specified parameters to AD.
    $TempPassword = "F@ll-CDT!2017"
    try {
        New-ADUser -Name $FullName -GivenName $FirstName -Surname $LastName -AccountPassword (ConvertTo-SecureString -String $TempPassword -AsPlainText -Force) `
            -EmailAddress $Email -SamAccountName $UserName -Enabled $true -Path "OU=Users,OU=CDT,DC=vase,DC=local" `
            -ChangePasswordAtLogon $false -DisplayName $FullName -UserPrincipalName "$UserName@vase.local"
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Warning -Message "The specified account ($UserName) already exists.  Continuing..."
        return
    }
    catch {
        Write-Error $_ 
        return
    }

    # Add new user to necessary groups
    foreach($Group in $Group) {
        Add-ADGroupMember -Identity $Group -Members $UserName
    }

    # Output overview of the actions above with relevant information
    Write-Host "`nAccount Creation Output:" -ForegroundColor Green
    Write-Host "New Account: $Username"
    Write-Host "Email: $Email"
    Write-Host "Groups added to: $Groups"
    Write-Host "Temporary Password: $TempPassword`n"
}

function Import-UsersFromCsv {
    Param (
        [Parameter(Mandatory=$true)]$CsvPath
    )

    $CSV = Import-Csv -Path $CsvPath

    foreach($person in $CSV) {
        if ($person.Team -eq 'A') {
            $Group = "Gray Team"
        }
        elseif ($person.Team -eq 'B') {
            $Group = "Red Team"
        }
        else {
            $Group = "Blue Team"
        }
        Add-VASEADUser -FirstName $person.FirstName -LastName $person.LastName -Email "$($person.Email)@g.rit.edu" -Groups $Group
    }
}