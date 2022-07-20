 # specify the path to the folder you want to monitor:
$Path = "\\172.17.5.17\Share1"

# specify which files you want to monitor
$FileFilter = 'movethisfolder.txt'  

# specify whether you want to monitor subfolders as well:
$IncludeSubfolders = $true

# specify the file or folder properties you want to monitor:
$AttributeFilter = [IO.NotifyFilters]::FileName, [IO.NotifyFilters]::LastWrite

Clear-host;

try
{
  $watcher = New-Object -TypeName System.IO.FileSystemWatcher -Property @{
    Path = $Path
    Filter = $FileFilter
    IncludeSubdirectories = $IncludeSubfolders
    NotifyFilter = $AttributeFilter
  }

  # define the code that should execute when a change occurs:
  $action = {
	
    # change type information:
    $details = $event.SourceEventArgs
    $Name = $details.Name
    $FullPath = $details.FullPath
    $OldFullPath = $details.OldFullPath
    $OldName = $details.OldName
    
    # type of change:
    $ChangeType = $details.ChangeType
    
    # when the change occured:
    $Timestamp = $event.TimeGenerated
    
	# let's compose a message:
	$text = "{0} was {1} at {2}" -f $FullPath, $ChangeType, $Timestamp
	Write-Host ""
	Write-Host $text -ForegroundColor DarkYellow
	
	# you can also execute code based on change type here:
	switch ($ChangeType)
	{
	  'Changed'  { "CHANGE" }
	  'Created'  { "CREATED"

        Write-host "Moving Folder: " $FullPath
		# Get-Content -Path $FullPath

	  }
	  'Deleted'  { "DELETED"
		# to illustrate that ALL changes are picked up even if
		# handling an event takes a lot of time, we artifically
		# extend the time the handler needs whenever a file is deleted
		Write-Host "Deletion Handler Start" -ForegroundColor Gray
		Start-Sleep -Seconds 4    
		Write-Host "Deletion Handler End" -ForegroundColor Gray
	  }
	  'Renamed'  { 
		# this executes only when a file was renamed
		$text = "File {0} was renamed to {1}" -f $OldName, $Name
		Write-Host $text -ForegroundColor Yellow

        Write-host "Moving Folder: " $FullPath

        # reading the trigger file, identifying the move destination path
        # should only include a single line with the resolveable UNC path
        # accessible by the instance that runs this script

        foreach($line in [System.IO.File]::ReadLines($FullPath))
            {
                   
                   $PathOnly = (Split-Path -Path $FullPath)
                   
                   Get-ChildItem -Path $PathOnly -Recurse | Move-Item -destination $line

            }

            Rename-Item -Path $FullPath -NewName "completed.txt" -Force

            # Schedule Pre-population Job for Metadata Refresh (using the CVO alias)

                Import-Module “C:\Program Files\TalonFAST\Bin\OptimusPSM.dll”

                # IMPORTANT: Update $PrepopPath with the relevant UNC path from Core -> Backend 

                $PrepopPath = "\\CVO\Share1";
                $StartTime = "20:00:00";
                $StartDateTime = "01-01-2022 20:00:00";
                $EndTime = "01-31-2099 06:00:00";
            
                $objFilter = Set-TLNPrePopulationPathFilter -UNCPath $PrePopPath -Metadataonly $true -Recurse $true
                $objFrequency = Set-TLNPrePopulationFrequency -Jobtype 1 -Value 1 -ExecuteAt $StartTime

                Add-TLNPrePopulationJob -AllEdgeServers -StartTime $StartDateTime -StopTime $EndTime -Filter $objFilter -Frequency $objFrequency

	  }
		
	  # any unhandled change types surface here:
	  default   { Write-Host $_ -ForegroundColor Red -BackgroundColor White }
	}
  }

  # subscribe your event handler to all event types that are
  # important to you. Do this as a scriptblock so all returned
  # event handlers can be easily stored in $handlers:
  $handlers = . {
    Register-ObjectEvent -InputObject $watcher -EventName Changed  -Action $action 
    Register-ObjectEvent -InputObject $watcher -EventName Created  -Action $action 
    Register-ObjectEvent -InputObject $watcher -EventName Deleted  -Action $action 
    Register-ObjectEvent -InputObject $watcher -EventName Renamed  -Action $action 
  }

  # monitoring starts now:
  $watcher.EnableRaisingEvents = $true

  Write-Host "Watching for changes to $Path"

  # since the FileSystemWatcher is no longer blocking PowerShell
  # we need a way to pause PowerShell while being responsive to
  # incoming events. Use an endless loop to keep PowerShell busy:
  do
  {
    # Wait-Event waits for a second and stays responsive to events
    # Start-Sleep in contrast would NOT work and ignore incoming events
    Wait-Event -Timeout 1

    # write a dot to indicate we are still monitoring:
    Write-Host "." -NoNewline
	
  } while ($true)
}
finally
{
  # this gets executed when user presses CTRL+C:
  
  # stop monitoring
  $watcher.EnableRaisingEvents = $false
  
  # remove the event handlers
  $handlers | ForEach-Object {
    Unregister-Event -SourceIdentifier $_.Name
  }
  
  # event handlers are technically implemented as a special kind
  # of background job, so remove the jobs now:
  $handlers | Remove-Job
  
  # properly dispose the FileSystemWatcher:
  $watcher.Dispose()
  
  Write-Warning "Event Handler disabled, monitoring ends."
} 
