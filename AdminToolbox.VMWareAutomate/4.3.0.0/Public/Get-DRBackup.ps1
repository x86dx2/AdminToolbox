Function Get-DRBackup {
    <#
    .DESCRIPTION
    The purpose of this function is to provide records that would simplify bringing back up a large vcenter array in a recovery scenario.

    Get's Domain DNS Records, Hosts, and VM's, saves the Gatered data to 3 separate spreadsheets, and prompts to Delete any files older than 45 days in the output path

    .PARAMETER DNSZone
    DNSZone that has records for the VMS and Hosts

    .PARAMETER PrimaryDNSServer
    Server that hosts the DNSZone

    .PARAMETER OutPath
    Path to save the output

    .PARAMETER VCenter
    Vcenter Server Host and VM data is pulled from

    .EXAMPLE
    Specify the DNS Zone Name containing the VMware DNS Records.
    Specify a Domain Controller containing the Primary DNS Zone.
    Specify the folder where the records are to be saved.
    Specify the Vcenter Server hosting the VM's.

    Get-DRRecords -DNSZone DNSZone.com -PrimaryDNSServer DNSServer -OutPath c:\drbackup -Vcenter vcentername

    .NOTES
    Requires the VMware.PowerCLI Module
    Requires the ImportExcel Module
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { if ($_ -notlike "*.*") { throw "DNS zone must specificy the Top Level Domain of the Zone. Like '.com' in MYZone.com" } else { $true } })]
        $DNSZone,
        [Parameter(Mandatory = $true)]$PrimaryDNSServer,
        [Parameter(Mandatory = $true)]$OutPath,
        [Parameter(Mandatory = $true)]$VCenter
    )

    $Required = Get-Module importexcel
    if ($null -eq $Required ) {
        Write-Warning "ImportExcel Module is Required"
    }

    else {
        #Get's DNS Records

        #Remove backslash from outpath variable to avoid outpath errors
        $Outpath = $Outpath.trimend("\")
        #Path Variables
        $date = Get-Date -format m
        $datepath = "$OutPath\$date DRBackup.xlsx"


        #Export Dns zone
        $results = Get-DnsServerResourceRecord -zonename $DNSZone -computername $PrimaryDNSServer | Select-Object hostname, Recordtype, timestamp, @{n = 'IP'; E = { $_.recorddata.IPV4Address } }
        $results | Export-Excel -WorksheetName "DNS" -Path "$datepath" -FreezeTopRow -TableName "$DNSZone" -AutoSize

        #connect vcenter
        Connect-VIServer -Server $VCenter

        #Get's vm list
        Get-VM * |
        Select-Object name, vmhost, @{N = "IP Address"; E = { @($_.guest.IPAddress -join '|') } }, NumCpu, CoresPerSocket, MemoryGB, Version, HardwareVersion, Notes |
        Export-Excel -WorksheetName "Virtual Machines" -Path "$datepath" -FreezeTopRow -TableName "Virtual Machines" -AutoSize

        #Get vmhosts
        Get-VMHost |
        Select-Object Name, @{n = "ManagementIP"; e = { Get-VMHostNetworkAdapter -VMHost $_ -VMKernel | Where-Object { $_.ManagementTrafficEnabled } | ForEach-Object { $_.Ip } } }, NumCpu, MemoryTotalGB, ProcessorType, LicenseKey, Version, Build |
        Export-Excel -WorksheetName "VM Hosts" -Path "$datepath" -FreezeTopRow -TableName "VMHosts" -AutoSize

        #Confirm the Function was successful by viewing the files have size to them
        Set-Location $OutPath
        Get-ChildItem | Sort-Object name -descending | Format-Table

        #Delete backup files older than 45 days
        Write-Host "WARNING: " -Foregroundcolor Red -NoNewline
        Write-Host "This will delete all files in the output path including those not generated by this function" -ForegroundColor Yellow
        $Prompt = Read-Host "Do you wish to delete all files in path older than 45 days? (yes/no)"

        if ($Prompt -eq 'yes') {
            cmd.exe /c forfiles /p "$OutPath" /d -45 /C "cmd /c del @path"
        }
        else {
            Write-Host "You selected No" -ForegroundColor Yellow
        }
    }
}