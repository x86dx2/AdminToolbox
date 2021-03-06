function Get-LockedAccounts {

    <#
    .Description
    Return a list of Locked Active Directory Accounts

    .Notes
    Requires the Active Directory Module

    .Link
    Get-DCLockoutEvents2
    Get-PasswordExpired
    Set-Password
    Unlock-Account
    Unlock-AllAccounts
    #>

    Import-Module ActiveDirectory

    Search-ADAccount -Lockedout |
    Select-Object Name, SamAccountName, UserPrincipalName |
    Sort-Object Name |
    Format-Table -AutoSize
}