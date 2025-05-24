# --------------------------
# BackupWithRobocopy.ps1
# --------------------------
# Description:
# This script performs a user-guided Robocopy backup with resume support, folder size confirmation,
# real-time log generation, and cleanup after successful runs. It uses GUI folder pickers,
# tracks backup state safely using a .tmp-to-.txt promotion method, and supports looped execution.
#
# Author: Turtlemonks
# Date: 2025-05-24
# --------------------------

# --------------------------
# Load Windows Forms assembly for folder picker dialogs
# --------------------------
Add-Type -AssemblyName System.Windows.Forms

# --------------------------
# UX pacing: global delay before showing dialogs
# --------------------------
$dialogDelaySeconds = 3

# --------------------------
# Function: Show-RobocopyFolderPicker
# --------------------------
# Displays a folder picker with description, pauses briefly for UX, and returns selected path or $null
function Show-RobocopyFolderPicker {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Description
    )

    try {
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = $Description
        $dialog.ShowNewFolderButton = $true

        Start-Sleep -Seconds $dialogDelaySeconds

        if ($dialog.ShowDialog() -eq 'OK') {
            return $dialog.SelectedPath
        } else {
            return $null
        }
    } catch {
        Write-Host "An error occurred while opening the folder picker." -ForegroundColor Red
        return $null
    }
}

# --------------------------
# Function: Get-RobocopyFolderSize
# --------------------------
# Recursively sums file sizes and returns total in readable format (TB, GB, MB, KB)
function Get-RobocopyFolderSize {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {
        $bytes = (Get-ChildItem -Path $Path -Recurse -ErrorAction Stop | Measure-Object -Property Length -Sum).Sum
        if ($bytes -ge 1TB) { return "{0:N2} TB" -f ($bytes / 1TB) }
        elseif ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
        elseif ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
        else { return "{0:N2} KB" -f ($bytes / 1KB) }
    } catch {
        return "Unknown size"
    }
}

# --------------------------
# Function: New-RobocopyLogFilePath
# --------------------------
# Creates log directory (C:\Logs if needed) and generates a timestamped log filename
function New-RobocopyLogFilePath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath
    )

    $logDir = "C:\Logs"
    if (-not (Test-Path $logDir)) {
        try {
            New-Item -Path $logDir -ItemType Directory -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "Failed to create log directory. Exiting." -ForegroundColor Red
            exit
        }
    }

    $folderName = Split-Path $SourcePath -Leaf
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    return Join-Path $logDir "Copy-$folderName-$timestamp.log"
}

# --------------------------
# Function: Start-RobocopyJob
# --------------------------
# Executes Robocopy using provided options and shows progress feedback
function Start-RobocopyJob {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Options,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Description
    )

    Write-Progress -Activity "Robocopy Backup In Progress" -Status "$Description..." -PercentComplete 0
    Write-Host "`nStarting backup: $Description" -ForegroundColor Green

    $command = "Robocopy `"$Source`" `"$Destination`" $Options"

    try {
        Invoke-Expression $command
    } catch {
        Write-Host "Robocopy encountered an error." -ForegroundColor Red
    }

    Write-Progress -Activity "Backup Complete" -Status "Done." -Completed
}

# --------------------------
# Main Execution Loop
# --------------------------
# Tracks backup state using temp and final resume files
# Resumes interrupted runs only if .txt exists (not just a temp)
# Cleans up temp/final state only after successful completion
do {
    Clear-Host
    Write-Host "----------------------------------------"
    Write-Host "Backup with Robocopy - Interactive Script"
    Write-Host "----------------------------------------"
    Write-Host "This script will back up a folder to a selected destination using Robocopy."
    Write-Host "You will be guided through folder selection, size confirmation, and backup execution."
    Write-Host ""

    # Define resume state paths (temporary and finalized)
    $stateFileFinal = "$env:USERPROFILE\Documents\LastRobocopyJob.txt"
    $stateFileTemp  = "$env:USERPROFILE\Documents\LastRobocopyJob.tmp"
    $resumeJob = $false

    # Prompt resume if a completed resume file exists
    if (Test-Path $stateFileFinal) {
        Write-Host "A previous backup job was found:" -ForegroundColor Yellow
        Get-Content $stateFileFinal | ForEach-Object { Write-Host "  $_" }
        $resumeChoice = Read-Host "Resume this backup job? (Y/N)"
        if ($resumeChoice -match '^[Yy]$') { $resumeJob = $true }
    }

    # Collect source/destination or reuse from resume
    if ($resumeJob) {
        $jobInfo = Get-Content $stateFileFinal
        $source = $jobInfo[0]
        $destination = $jobInfo[1]
    } else {
        Write-Host "`nPreparing to select the SOURCE folder to back up..."
        $source = Show-RobocopyFolderPicker -Description "Select the folder you want to back up"
        if (-not $source) { Write-Host "No source folder selected. Exiting." -ForegroundColor Red; break }

        Write-Host "`nPreparing to select the DESTINATION folder for the backup..."
        $destination = Show-RobocopyFolderPicker -Description "Select the destination folder"
        if (-not $destination) { Write-Host "No destination folder selected. Exiting." -ForegroundColor Red; break }

        # Write temp file to track resume state
        "$source`n$destination" | Set-Content $stateFileTemp
    }

    # Report sizes for user verification
    $sourceSize = Get-RobocopyFolderSize -Path $source
    $destinationSize = Get-RobocopyFolderSize -Path $destination

    Write-Host "`nBackup configuration summary:"
    Write-Host "  Source:      $source  ($sourceSize)"
    Write-Host "  Destination: $destination  ($destinationSize)"
    $confirm = Read-Host "Proceed with backup? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Backup cancelled." -ForegroundColor Yellow
        # Cleanup temp state on cancel
        if (Test-Path $stateFileTemp) { Remove-Item $stateFileTemp -Force }
        continue
    }

    # Set log file path and choose Robocopy options
    $logFile = New-RobocopyLogFilePath -SourcePath $source

    if (-not $resumeJob) {
        Write-Host "`nSelect backup mode:"
        Write-Host "1. Full Copy (copies all files and folders)"
        Write-Host "2. Incremental Mirror (sync changes and remove missing files)"
        $mode = Read-Host "Enter 1 or 2"

        switch ($mode) {
            '1' {
                $options = "/E /COPYALL /DCOPY:T /Z /NP /R:3 /W:5 /LOG:`"$logFile`""
                $desc = "Full Copy"
            }
            '2' {
                $options = "/MIR /COPYALL /DCOPY:T /Z /NP /R:3 /W:5 /LOG:`"$logFile`""
                $desc = "Incremental Mirror"
            }
            default {
                Write-Host "Invalid selection. Exiting." -ForegroundColor Red
                break
            }
        }
    } else {
        $options = "/E /COPYALL /DCOPY:T /Z /NP /R:3 /W:5 /LOG:`"$logFile`""
        $desc = "Resuming Previous Copy"
    }

    # Start Robocopy execution
    Start-RobocopyJob -Source $source -Destination $destination -Options $options -Description $desc

    Write-Host "`nBackup completed. Log file saved to: $logFile" -ForegroundColor Green

    # Promote .tmp to .txt only if backup completed
    if (Test-Path $stateFileTemp) {
        Move-Item -Path $stateFileTemp -Destination $stateFileFinal -Force
    }

    # Clean up resume state after success
    if (Test-Path $stateFileFinal) {
        Remove-Item $stateFileFinal -ErrorAction SilentlyContinue
    }

    # Loop if user wants another backup
    $again = Read-Host "`nWould you like to run another backup? (Y/N)"
}
while ($again -match '^[Yy]$')
