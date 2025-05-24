# BackupWithRobocopy.ps1

## Overview

This script provides an interactive, user-friendly backup solution using Robocopy. It supports resumable jobs, folder size validation, timestamped logging, GUI folder pickers, and robust error handling — making it ideal for repeatable backups across large file structures like media libraries or shared drives.

---

## Features

- ✅ **Graphical folder selection**
- ✅ **Resume support** after cancellation or reboot (uses `.tmp` → `.txt` tracking)
- ✅ **Log file generation** in `C:\Logs` with timestamp and source folder name
- ✅ **Human-readable size reporting**
- ✅ **Backup mode selection**: Full Copy or Incremental Mirror
- ✅ **Loopable execution** (runs again after completion if user chooses)
- ✅ **Clean PowerShell 5.1 compatibility** with modular functions and approved verbs

---

## Requirements

- PowerShell 5.1 (default on Windows 10 and 11)
- Administrative privileges recommended (for writing to C:\Logs)
- No additional modules required

---

## How to Use

1. Download and place `BackupWithRobocopy.ps1` on your system
2. Run the script with PowerShell (right-click → *Run with PowerShell* OR run from terminal)
3. Follow the on-screen prompts:
   - Select source and destination folders via dialog
   - Review folder sizes
   - Choose backup mode
   - Optionally resume previous job (if one was in progress)
4. View logs at `C:\Logs\Copy-[FolderName]-[Timestamp].log`

---

## Backup Modes Explained

| Mode              | Description                                                                 |
|-------------------|-----------------------------------------------------------------------------|
| **Full Copy**     | Copies all files and folders, preserving metadata. Safe and non-destructive.|
| **Incremental Mirror** | Mirrors folder structure: removes destination files not in source.      |

---

## Resume Behavior

- A temporary job file (`LastRobocopyJob.tmp`) is created after folder selection
- If backup completes successfully, it promotes to `.txt` and is removed
- If backup is interrupted (e.g., crash, power loss), `.tmp` remains unpromoted
- On next launch, resume will **only be prompted if `.txt` exists**

---

## Customization

- Change `$dialogDelaySeconds` (default = `3`) to control how long the script waits before showing folder dialogs
- Modify the `$logDir` inside `New-RobocopyLogFilePath` to change log location
- Add custom Robocopy options inside `Start-RobocopyJob` if needed

---

## License

MIT License. Feel free to use, modify, or redistribute with attribution.

---

## Author

**Turtlemonks**  
© 2025
