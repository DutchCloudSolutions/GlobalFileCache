 #############################################################################################################
##
##  EdgeToCoreFO.ps1
##
##  Date: December 6, 2021 
##  By: Jaap van Duijvenbode (vjaap@netapp.com)
##  Version: 1.3
##
##  Description: EdgeToCore Failover / Failback script to orchestrate failover of Edge instances
##               to alternate core instances, e.g. in secondary region (DR)
##
##  - Primary GFC Core ILB: jvd-hacore.netappgfc.com
##  - Primary GFC Nodes: jvd-hacore001 / jvd-hacore002 (hot standby)
##
##  - DR GFC Core (no ILB): jvd-drcore001.netappgfc.com
##
##  - GFC Alias name: edgetocore.netappgfc.com (C-Name)
##
##  Dependencies:   - Domain Administrative Credentials
##                  - RSAT for Active Directory on local host running PowerShell
##                  - Basic Authentication / Authorization associated with PowerShell Remoting / WINRM
##
##  Future Work:    - Automatically determine which REGION is up and down, if both choose PRI (COMPLETED)
##                  - Check this based on Socket Connect on 6676 (Health Probe Port) (COMPLETED)
##                  - Define Array of Edge instances, i.e. query OU in AD instead of string value like
##                  - Validate Edge Tum settings are corresponding to correct Fabric ID and FQDN alias
##                  - Query GFC Core NASDb configuration and confirm connectivity and enumeration of shares
##
##  Failover Modes: - Current logic is built on Edge-to-Core services and associations, there is no
##                    logic built-in (yet) that couples the backend storage platform in case GFC Core is up,
##                    but CVO is down. We may need to query the GFC core's ability to connect 139/445 to the
##                    central file shares to confirm that the SVM's are up.
##
#############################################################################################################

Clear-Host;

Write-Host ""
Write-Host ""
Write-Host "=-=-=-=-=-=-=-=-= Global File Cache Edge-to-Core Region Failover/Failback =-=-=-=-=-=-=-="
Write-Host ""
Write-Host "                         by Jaap van Duijvenbode (vjaap@netapp.com)"
Write-Host ""
Write-Host "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="


$cGFCAliasName = "edgetocore"                    ## Edge to Core alias 
$cGFCPriHostName = "jvd-hacore.netappgfc.com"    ## ILB hostname
$cGFCSecHostName = "jvd-drcore001.netappgfc.com" ## DR hostname
$cADZoneName = "netappgfc.com"                   ## DNS AD-integrated zone
$cADDNS = "netappgfccom-ad"                      ## DNS Server Name 

## Test Network Connection to possible GFC Core ILB or instances, probing TCP 6676

$cGFCPrimaryUp = Test-netconnection -Computername $cGFCPriHostName -Port 6676
$cGFCSecondaryUp = Test-netconnection -Computername $cGFCSecHostName -Port 6676

If ($cGFCPrimaryUp.TcpTestSucceeded)
{
    Write-Host "Primary Region is UP, selecting Primary Region as Target" -BackgroundColor DarkGreen -ForegroundColor White
    $nTarget = 1
}
Else
{
   Write-Host "Primary Region is DOWN, trying Secondary Region as Target"  -BackgroundColor DarkCyan -ForegroundColor Yellow
   If ($cGFCSecondaryUp.TcpTestSucceeded)
   {
       Write-Host "Secondary Region is UP, selecting Secondary Region as Target" -BackgroundColor DarkCyan -ForegroundColor Yellow
       $nTarget = 2
   }
   Else
   {
       Write-Host "WARNING: Both GFC Primary and Secondary Regions are DOWN" -BackgroundColor Black -ForegroundColor Red
       $nTarget = 0
       Exit
   } 
}

## $nTarget = 2 ## CHANGE TO 1 or 2 TO OVERRIDE DESTINATION REGION

$DNSServer = New-PSSession -ComputerName $cADDNS ## AD DNS Server / Domain Controller

## Adjusting DNS Records, updating edgetocore C-Name with A-Record corresponding to Pri or Sec ILB or hostname

If ($nTarget -eq 1) {
  
    Write-Host "Failing BACK to Primary Region" $cGFCPriHostName -BackgroundColor DarkGreen -ForegroundColor White
    Invoke-Command $DNSServer -ScriptBlock {param($cGFCPriHostName, $cGFCAliasName, $cADZoneName) Add-DnsServerResourceRecordCName -HostNameAlias $cGFCPriHostName -Name $cGFCAliasName -ZoneName $cADZoneName -AllowUpdateAny} -ArgumentList ($cGFCPriHostName, $cGFCAliasName, $cADZoneName) -erroraction 'silentlycontinue' ## PRI Core

  }  Else {

    Write-Host "Failing OVER to Secondary Region" $cGFCSecHostName -BackgroundColor DarkCyan -ForegroundColor Yellow
    Invoke-Command $DNSServer -ScriptBlock {param($cGFCSecHostName, $cGFCAliasName, $cADZoneName) Add-DnsServerResourceRecordCName -HostNameAlias $cGFCSecHostName -Name $cGFCAliasName -ZoneName $cADZoneName -AllowUpdateAny} -ArgumentList ($cGFCSecHostName, $cGFCAliasName, $cADZoneName)  -erroraction 'silentlycontinue' ## DR Core
} 

Remove-PSSession -ComputerName $cADDNS

## Running the following commands on each GFC Edge instance in sequence:
##       - Stop TService on all GFC Edge instances
##       - Flush DNS Resolver Cache on respective Edges
##       - Sleep for 2 seconds (optional)
##       - Restart Tservice on respective GFC Edges
##

## $Computers = (Get-ADComputer -filter  "Name -like 'JVD*EDGE1'").Name 

$Computers = (Get-ADComputer -filter * -SearchBase "OU=Jaap, DC=netappgfc, DC=com").Name

Invoke-Command -ComputerName $Computers -Script {Stop-Service TService; Clear-DnsClientCache; Start-Sleep 2; Start-Service TService} 

## Invoke-Command -Computer $cGFCPriHostName -ScriptBlock {Get-ItemProperty -Path: HKLM:TALON\Tum\Server\NasDb\CVO -Name Alias}
## Get-ChildItem -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\'
##
## Traverse HKLM:TALON\Tum\Server\NasDb\ put every KEY in array
## for each key find ALIAS and put in array
## Perform remote Test-NetConnection from CORE to CVO on TCP 139/445 to connect to SMB endpoint, validating that CVO is ONLINE
##
##
## $Registry = Get-ChildItem -Path 'HKLM:\Talon\Tum\Server\NasDB\'

## for each 
## $Registry = Get-ItemProperty -path 'HKLM:\Talon\Tum\Server\NasDB\CVO\'
## $Registry.Alias

## Invoke-Command -ComputerName DC1 -ScriptBlock {
## Get-ChildItem "HKLM:\Talon\Tum\Server\NasDB\" -Recurse | ForEach-Object {
##   $regkey = (Get-ItemProperty $_.PSPath) | Where-Object { $_.PSPath -match 'debug' }
##   if ($Using:masterList.Contains($_.Name)) #Check if the reg key is in master list
##        {
##               Set-ItemProperty -Path $regkey.PSPath -Name $_.Name -Value 1
##        }
##} 
## }