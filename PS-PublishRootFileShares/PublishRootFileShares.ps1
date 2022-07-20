#####################################################################################################################
##
##  PublishRootFileShares.ps1
##
##  Date: May 12, 2022 
##  By: Jaap van Duijvenbode (vjaap@netapp.com)
##  Version: 1.2
##
##  Description: This script reshares file shares from FASTData as root file shares on this GFC Edge
##               It is designed to traverse the backend file server share list, and create new root
##               file shares to allow namespace transparency when 1:1 replacing NAS at the edge 
##
##  Future work: 
##               - Remove dependency of T: CacheMountPoint, can we use TafsMtPt ?
##               - Traverse the root of the fabric based on HKLM\TALON\Tum\Client\ServerDB name (COMPLETED)
##               - Skip 127.0.0.1 whilst traversing backends and ONLY select the first backend listed (COMPLETED)
##               - Ensure DisableStrictNameChecking registry key is enabled to allow C-Name access
##
#####################################################################################################################


Clear-Host;

## Identify Primary Fabric ID

$cFabric = Get-ChildItem –Path "\\Localhost\FASTData\" -Directory

## Identify Primary Backend File Server, whilst excluding 127.0.0.1

ForEach($cBackend in Get-ChildItem -Path "\\Localhost\FASTData\$cFabric"){ 

    If ($cBackend -notmatch '127.0.0.1') {
    $cFullPath = "\\Localhost\FASTDATA\" + $cFabric + "\" + $cBackend 
    Break
    }
} 


##
## Traverse the backend file server associated with SVM or Vfiler
##

Get-ChildItem –Path $cFullPath |

Foreach-Object {


$cPath = "T:\$cFabric\$cBackend\$_"
$cShare = $_

    ##
    ## Create new root file shares
    ##

    Write-Host "Creating root file share for: $_ using path " $cPath

    ## Skip if File Share exists, otherwise create new root share 

    if(!(Get-SMBShare -Name $cShare -ea 0)){
    New-SmbShare -Name "$cShare" -Path "$cPath" -FullAccess "Everyone"
    }

    ##
    ## Clean up all root shares
    ## Remove-SmbShare -Name "$cShare"
    ##

} 
