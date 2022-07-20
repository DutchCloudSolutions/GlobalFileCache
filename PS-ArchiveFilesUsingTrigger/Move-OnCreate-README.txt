NOTE: The process outlined below and scripts attached are not developed, supported and maintained by NetApp, or previously TALON. These materials have been provided by customers and the Microsoft community who leverage customized data management options, based on Windows Server, PowerShell integrating with SMB/CIFS backend platforms.

This script's original purpose is to delegate administrative control of backend file server data moves. Which allows a backend process to move data from one file location to the other in real-time by creating a 'trigger' file named movethisfolder.txt which contains a single line with the destination target UNC path relative to the File System watcher VM instance (i.e. the GFC LMS server) connected to the central data store.

As this file system watcher runs interactively as a service it will monitor the respective folder locations, it is designed to read meta-data to understand any incremental changes to the (sub)folders, explicitly looking for the movethisfolder.txt file and subsequently taking action to perform a (Move-Item) PowerShell cmdlet.
 
IMPORTANT: It is unknown and untested what the impact is on the backend file system, whether it triggers rehydration of 'cold' data from object storage tiers and whether this introduces any incremental cost or performance degradation on the central file store. Once more, this script has been provided by customers to share with the community.
 
This is a real-time process, which should run as a service. If the process, the File System Watcher, does not run, none of the movethisfolder.txt files will be picked up for execution. The only way to (re)trigger the folder move is by renaming the file so the process picks it up for execution.
 
User Workflow:
 
User creates a new text document on the LIVE folder directly on the backend file server of via the GFC Edge instance to trigger a backend data move from LIVE to ARCHIVE
Within the document, specify the target UNC path, i.e. \\172.17.5.17\Share1\Archive which represents the ARCHIVE location
Rename the document to movethisfolder.txt, which will trigger the server process (File System Watcher)
The File System Watcher will process the 'renamed' file, reading the movethisfolder.txt file and capturing the first line as a UNC path for the ARCHIVE location 

** BEWARE: NO DYNAMIC CHECKS ARE INCLUDED, SYNTAX ERROR MAY RESULT IN DATA LOSS ** 
 
Once the file has been moved, the folder will be moved to the destination location, i.e. from \\Edge\FASTData\Azure\CVO\Share1\Test\ , which corresponds to \\172.17.5.17\Share1\ to the archive location, i.e. \\172.17.5.17\Archive
Once the Move process completes, the movethisfolder.txt file is renamed to completed.txt

Note: any open handles may cause incomplete move process, in this case rename the file, subsequently triggering an incremental move of this folder.
Subsequently, a Pre-population job is scheduled to update all the meta-data for the root share, which is scheduled to run on EACH edge instance

Automated pre-population REQUIRES you to run the script from the GFC LMS server instance, which holds the Pre-population jobs / policies associated.
For more information on the GFC Prepopulation PowerShell cmdlets, consult the GFC User Guide
 
I have recorded a walk-through demo on my private YT channel at https://youtu.be/CRQu0xINFYQ to provide you an example and some feedback on how the script may help to orchestrate the backend move process. 
Again, this is a customer / community contribution, none of this is maintained by NetApp and should be adjusted to customer's needs.
 
As customers leveraged most of the publicly available code, the following source was used:
https://powershell.one/tricks/filesystem/filesystemwatcher

All Code samples are licensed under a Attribution 4.0 International license. 
Use, share, and experiment freely.
