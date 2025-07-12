# Justin Verstijnen Server Install Updates and Restart script
# Github page: https://github.com/JustinVerstijnen/JV-ServerPeriodicInstallUpdates
# Let's start!
Write-Host "Script made by..." -ForegroundColor DarkCyan
Write-Host "     _           _   _        __     __            _   _  _                  
    | |_   _ ___| |_(_)_ __   \ \   / /__ _ __ ___| |_(_)(_)_ __   ___ _ __  
 _  | | | | / __| __| | '_ \   \ \ / / _ \ '__/ __| __| || | '_ \ / _ \ '_ \ 
| |_| | |_| \__ \ |_| | | | |   \ V /  __/ |  \__ \ |_| || | | | |  __/ | | |
 \___/ \__,_|___/\__|_|_| |_|    \_/ \___|_|  |___/\__|_|/ |_| |_|\___|_| |_|
                                                       |__/                  " -ForegroundColor DarkCyan

# === PARAMETERS ===
$logFile = Join-Path -Path $PSScriptRoot -ChildPath "JV-ServerPeriodicInstallUpdates-Log_$(Get-Date -Format dd-MM-yyyy).txt"

# === END PARAMETERS ===

function Trim-LogFile {
    param(
        [string]$logFilePath,
        [int]$maxSizeKB = 100
    )

    if (Test-Path $logFilePath) {
        $fileInfo = Get-Item $logFilePath
        while ($fileInfo.Length -gt ($maxSizeKB * 1024)) {
            $lines = Get-Content $logFilePath
            $lines = $lines[10..($lines.Length - 1)]
            Set-Content -Path $logFilePath -Value $lines
            $fileInfo = Get-Item $logFilePath
        }
    }
}

# Step 1: First check if the script runs as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Warning "This script must be runned as Administrator. The script will now end."
    exit
}


# Step 2: Logging will be enabled for checking the functionality of the script, even after it ran unattended.
function Log {
    param ($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}
Log ""


# Step 3: Checking and Installing the latest Windows Updates
Log "=== STEP 3: WINDOWS UPDATES ==="

try {
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Log "Installing 'PSWindowsUpdate' module..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -AllowClobber
        Log "'PSWindowsUpdate' module is now installed."
    } else {
        Log "'PSWindowsUpdate' module was already installed. Advancing to checking and installation."
    }

    Import-Module PSWindowsUpdate -Force
} catch {
    Log "ERROR: Failed to install or import PSWindowsUpdate module: $_"
    return
}

try {
    # List available updates
    $availableUpdates = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot

    if (-not $availableUpdates -or $availableUpdates.Count -eq 0) {
        Log "No updates available."
    } else {
        Log "Found $($availableUpdates.Count) update(s):"
        $availableUpdates | ForEach-Object {
            Log " - $($_.Title)"
        }

        Log "Beginning update installation..."

        foreach ($update in $availableUpdates) {
            try {
                Log "Installing update: $($update.Title)"
                $result = Install-WindowsUpdate -KBArticleID $update.KBArticleIDs -AcceptAll -IgnoreReboot -Confirm:$false -MicrosoftUpdate -Verbose:$false

                if ($result -and $result.RebootRequired) {
                    Log " -> Installed. Reboot required: $($update.Title)"
                } else {
                    Log " -> Installed successfully: $($update.Title)"
                }
            } catch {
                Log "ERROR: Failed to install update $($update.Title): $_"
            }
        }

        Log "Update installation process complete."
    }
} catch {
    Log "ERROR during Windows Update process: $_"
}
Log "=== SCRIPT COMPLETED ==="


# Step 4: Server restart to apply the installed updates
Log "=== SERVER WILL NOW REBOOT ==="
Restart-Computer -Force