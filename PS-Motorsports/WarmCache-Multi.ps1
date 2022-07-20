###################################################################################################
##
##  WarmCache-Multi.ps1
##
##  Date: February 5, 2021 
##  By: Jaap van Duijvenbode (vjaap@netapp.com)
##  Version: 1.2
##
##  Description: Multi-threaded script that traverses a folder structure recursively and  
##               opens each file/folder that is not in the $nExcludeFileTypes collection or 
##               is not a reparse point, i.e. DFS Namespace folder. 
##
##               This script performs the same action as a GFC prepop job, but can be ran
##               on-demand at any given time to 'force' fetch of cold or warm files. 
##
##  Future work: 
##               - Include additional parameters, i.e. skipping files > 30 days (COMPLETED)
##               - Stop the job at a given time
##               - Adding dynamic checks and error handling for rogue conditions
##               - Do not try to fetch folder content, but just traverse (COMPLETED)
##               - Monitor CPU usage to circumvent excessive utilization
##
###################################################################################################

$fileDirectory = "\\LOCALHOST\FASTDATA\AZURE-EUS2\JVD-GFCCORE1\Data\Sampledata";    ## File directory to be fetched recursively
$cExcludeFileTypes = "db","tmp";                                                    ## File types to be excluded from fetch, syntax: "xlsx", "docx"
$nFileSize = 0;                                                                     ## Gather total file size
$nFileCount = 0;                                                                    ## Count total number of files
$nLastAccessDays = -180;                                                            ## Last X days of accessed data (-30 = last 30 days)
$nLastWriteDays = -180;                                                             ## Last X days of modified data  (-30 = last 30 days)

$ErrorActionPreference = 'silentlycontinue';                                        ## Suppress error messages, i.e. Access Denied

$Worker = {
    param($Filename)
    Write-host "Fetching data for: " $Filename

    ## Enable/disable below Get-Content command for full file fetch or meta data only 

    Get-Content -Path $Filename
   
}

$MaxRunspaces = 10

$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxRunspaces)
$RunspacePool.Open()

$Jobs = New-Object System.Collections.ArrayList

Clear-Host;

Write-Host "Job started at: " (get-date).ToString()

foreach($fileDirectory in Get-ChildItem -Path $fileDirectory -Force -Recurse)
 {
     
   $cFileAttr = $fileDirectory.Attributes.ToString()

   ## Get file type from $cFileType = $fileDirectory.Filetype

   $cFileType = $fileDirectory.name
   $cFileType = $cFileType.Split(".")[-1]

   ## Excluding Reparse Points and specific file types


   if(($cFileAttr -inotmatch 'ReparsePoint') -and ($cExcludeFileTypes -notcontains $cFileType)) 
   {

         ## Identify cold or warm file

        if ($cFileAttr -match 'Offline')
          {
            $cFileCacheType = "Cold"

          }
        else
          {
           $cFileCacheType = "Warm"

          }
        

        ## change operator to define behavior, currently files modified OR accessed -x days are fetched
        ## to meet both conditions, change operator to AND

        if ($fileDirectory.LastWriteTime -ge (Get-Date).AddDays($nLastWriteDays) -or $fileDirectory.LastAccessTime -ge (Get-Date).AddDays($nLastAccessDays))
        {
            Write-host "Fetching ($cFileCacheType) (meta)data for: " $fileDirectory.FullName " Last Accessed: " $fileDirectory.LastAccessTime " Last Written: " $fileDirectory.LastWriteTime
    
            $PowerShell = [powershell]::Create()
	        $PowerShell.RunspacePool = $RunspacePool
            $PowerShell.AddScript($Worker).AddArgument($fileDirectory.FullName) | Out-Null
    
           $nFileCount = $nFileCount + 1
           $nFileSize = $nFileSize + $fileDirectory.Length
        }

    $JobObj = New-Object -TypeName PSObject -Property @{
		Runspace = $PowerShell.BeginInvoke()
		PowerShell = $PowerShell  
    }

    $Jobs.Add($JobObj) | Out-Null
    }
}

while ($Jobs.Runspace.IsCompleted -contains $false) {
    Write-Host (Get-date).Tostring() "Still running..."
	Start-Sleep 5

    ## monitor time for stop/start date

}

Write-Host "Total amount of data: " $nFileSize
Write-Host "Total number of files: " $nFileCount
Write-Host "Job completed at: " (get-date).ToString() 
