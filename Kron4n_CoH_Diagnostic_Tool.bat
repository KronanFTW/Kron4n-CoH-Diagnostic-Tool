@echo off
setlocal EnableExtensions
title Kron4n - Company of Heroes Diagnostic Tool
mode con cols=92 lines=42
color 0A

set "TMPPS=%TEMP%\Kron4n_CoH_Diagnostic_%RANDOM%%RANDOM%.ps1"
set "THISBAT=%~f0"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$content = Get-Content -LiteralPath $env:THISBAT; $marker = [Array]::IndexOf($content, '::POWERSHELL_SCRIPT_BELOW'); if ($marker -lt 0) { exit 2 }; $content[($marker + 1)..($content.Length - 1)] | Set-Content -LiteralPath $env:TMPPS -Encoding UTF8"
if errorlevel 1 (
    echo.
    echo Failed to extract the embedded diagnostic script.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%TMPPS%"
set "EXITCODE=%ERRORLEVEL%"

del "%TMPPS%" >nul 2>&1
exit /b %EXITCODE%

::POWERSHELL_SCRIPT_BELOW
$ErrorActionPreference = 'SilentlyContinue'

try {
    $Host.UI.RawUI.WindowTitle = "Kron4n - Company of Heroes Diagnostic Tool"
    $Host.UI.RawUI.ForegroundColor = 'Green'
    $Host.UI.RawUI.BackgroundColor = 'Black'
} catch {}

try {
    Clear-Host
} catch {}

function Write-Banner {
    Write-Host ''
    Write-Host '  ############################################################################'
    Write-Host '  #                                                                          #'
    Write-Host '  #      KK   KK RRRRR    OOOOO   NN   NN  4444    NN   NN                   #'
    Write-Host '  #      KK  KK  RR  RR  OO   OO  NNN  NN 44 44    NNN  NN                   #'
    Write-Host '  #      KKKK    RRRRR   OO   OO  NN N NN 444444   NN N NN                   #'
    Write-Host '  #      KK  KK  RR  RR  OO   OO  NN  NNN    44    NN  NNN                   #'
    Write-Host '  #      KK   KK RR   RR  OOOOO   NN   NN    44    NN   NN                   #'
    Write-Host '  #                                                                          #'
    Write-Host '  #                  COMPANY OF HEROES DIAGNOSTIC TOOL                       #'
    Write-Host '  #                  INSTALLATION AND MOD FILE REPORT                        #'
    Write-Host '  #                                                                          #'
    Write-Host '  #                         Created by Kron4n                                #'
    Write-Host '  #                                                                          #'
    Write-Host '  ############################################################################'
    Write-Host ''
    Write-Host "        Creates:"
    Write-Host "        Kron4n's_diagnostic_log.txt on the Desktop"
    Write-Host ''
    Write-Host '        Read-only scan:'
    Write-Host '        No files are moved, copied, deleted, or changed.'
    Write-Host ''
    Write-Host '  ############################################################################'
    Write-Host ''
    Write-Host '        Starting read-only diagnostic scan...'
    Write-Host '        This may take a while on systems with large drives.'
    Write-Host ''
}

Write-Banner

$DesktopPath = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($DesktopPath) -or -not (Test-Path -LiteralPath $DesktopPath)) {
    $DesktopPath = Join-Path $env:USERPROFILE 'Desktop'
}

$PreferredLogPath = Join-Path $DesktopPath "Kron4n's_diagnostic_log.txt"
$FallbackLogPath = Join-Path $env:TEMP "Kron4n's_diagnostic_log.txt"
$script:LogPath = $PreferredLogPath
$LogReady = $false
$LogFallbackUsed = $false

foreach ($CandidateLogPath in @($PreferredLogPath, $FallbackLogPath)) {
    try {
        Set-Content -LiteralPath $CandidateLogPath -Value @() -Encoding UTF8 -ErrorAction Stop
        $script:LogPath = $CandidateLogPath
        $LogReady = $true
        if ($CandidateLogPath -eq $FallbackLogPath) {
            $LogFallbackUsed = $true
        }
        break
    } catch {}
}

if (-not $LogReady) {
    Write-Host ''
    Write-Host 'ERROR: The diagnostic log file could not be created.'
    Write-Host 'The tool will now close.'
    Write-Host ''
    [void](Read-Host 'Press Enter to close')
    exit 1
}

function Add-Line {
    param(
        [AllowEmptyString()]
        [string]$Text = ''
    )

    Write-Host $Text
    Add-Content -LiteralPath $script:LogPath -Value $Text -Encoding UTF8
}

function Add-Section {
    param(
        [string]$Title
    )

    Add-Line ''
    Add-Line '============================================================'
    Add-Line $Title
    Add-Line '============================================================'
}

function Format-Values {
    param(
        [object[]]$Values
    )

    $SafeValues = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($SafeValues.Count -eq 0) {
        return 'None'
    }

    return ($SafeValues -join ', ')
}

function Get-CohFolderRole {
    param(
        [string]$Path
    )

    $RelicExePath = Join-Path $Path 'RelicCOH.exe'
    $HasRelicExe = Test-Path -LiteralPath $RelicExePath -PathType Leaf
    $LeafName = Split-Path -Leaf $Path

    if ($Path -match '\\Documents\\My Games\\Company of Heroes Relaunch$' -or $Path -match '\\WinMyDocuments\\my games\\Company of Heroes Relaunch$') {
        return 'USER_DATA'
    }

    if ($LeafName -match '^Company of Heroes Relaunch\s*-\s*Backup$' -or $LeafName -match '^Company of Heroes Relaunch\s+backup$') {
        if ($HasRelicExe) {
            return 'BACKUP_GAME'
        }

        return 'BACKUP_OR_MANUAL'
    }

    if ($HasRelicExe) {
        return 'ACTIVE_GAME'
    }

    return 'OTHER'
}

function Get-CohFolderRoleLabel {
    param(
        [string]$Role
    )

    switch ($Role) {
        'ACTIVE_GAME' {
            return 'Active real CoH game folder'
        }
        'BACKUP_GAME' {
            return 'Backup/manual CoH game copy with RelicCOH.exe'
        }
        'BACKUP_OR_MANUAL' {
            return 'Backup/manual copy without RelicCOH.exe'
        }
        'USER_DATA' {
            return 'User data folder'
        }
        default {
            return 'Folder without RelicCOH.exe'
        }
    }
}

function Get-LegacyFolderRole {
    param(
        [string]$Path
    )

    $RelicExePath = Join-Path $Path 'RelicCOH.exe'
    $HasRelicExe = Test-Path -LiteralPath $RelicExePath -PathType Leaf

    if ($Path -match '\\Documents\\My Games\\Company of Heroes$' -or $Path -match '\\WinMyDocuments\\my games\\Company of Heroes$') {
        return 'LEGACY_USER_DATA'
    }

    if ($HasRelicExe) {
        return 'LEGACY_GAME'
    }

    return 'LEGACY_FOLDER_ONLY'
}

function Get-LegacyFolderRoleLabel {
    param(
        [string]$Role
    )

    switch ($Role) {
        'LEGACY_GAME' {
            return 'Legacy/old Company of Heroes game folder candidate with RelicCOH.exe'
        }
        'LEGACY_USER_DATA' {
            return 'Legacy/old Company of Heroes user data folder'
        }
        default {
            return 'Folder named Company of Heroes without RelicCOH.exe'
        }
    }
}

function Get-ModFindings {
    param(
        [pscustomobject]$Mod,
        [string[]]$CohPaths
    )

    $Results = @()

    foreach ($CohPath in @($CohPaths)) {
        $FolderRole = Get-CohFolderRole -Path $CohPath

        # Ignore user-data folders in the mod installation check.
        # They can contain save/config folders with mod-like names, but they are not mod install locations.
        if ($FolderRole -eq 'USER_DATA') {
            continue
        }

        $ModuleHits = @()
        foreach ($ModuleFile in @($Mod.Modules)) {
            $ModulePath = Join-Path $CohPath $ModuleFile
            if (Test-Path -LiteralPath $ModulePath -PathType Leaf) {
                $ModuleHits += $ModuleFile
            }
        }

        $FolderHits = @()
        foreach ($FolderName in @($Mod.Folders)) {
            $FolderPath = Join-Path $CohPath $FolderName
            if (Test-Path -LiteralPath $FolderPath -PathType Container) {
                $FolderHits += $FolderName
            }
        }

        if ($ModuleHits.Count -gt 0 -or $FolderHits.Count -gt 0) {
            $IsCompletePair = ($ModuleHits.Count -gt 0 -and $FolderHits.Count -gt 0)

            $Results += [pscustomobject]@{
                Path       = $CohPath
                Role       = $FolderRole
                Modules    = @($ModuleHits)
                Folders    = @($FolderHits)
                Complete   = $IsCompletePair
            }
        }
    }

    return @($Results)
}

Add-Line '  ############################################################################'
Add-Line ''
Add-Section "Kron4n's Company of Heroes Diagnostic Report"
Add-Line 'Tool version: 1.4'
Add-Line ("Created: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Add-Line ("Log file: {0}" -f $script:LogPath)
Add-Line 'Mode: Read-only diagnostic scan. No files are moved, copied, deleted, or changed.'
Add-Line 'Scan scope: Locally attached fixed and removable drives are scanned. Mapped network drives are skipped. Relaunch and legacy folder names are checked.'
Add-Line 'Note: Full-drive searches can take a while on large drives.'
if ($LogFallbackUsed) {
    Add-Line 'Warning: The Desktop log path was unavailable, so the log was saved in the Windows Temp folder instead.'
}

Add-Section 'Drive scan'
$AllDetectedDrives = @(
    [System.IO.DriveInfo]::GetDrives() |
        Sort-Object Name
)

$NetworkDriveRoots = @(
    $AllDetectedDrives |
        Where-Object { $_.DriveType -eq [System.IO.DriveType]::Network } |
        ForEach-Object { $_.Name } |
        Sort-Object -Unique
)

$LocalCandidateDriveRoots = @(
    $AllDetectedDrives |
        Where-Object {
            $_.DriveType -eq [System.IO.DriveType]::Fixed -or
            $_.DriveType -eq [System.IO.DriveType]::Removable
        } |
        ForEach-Object { $_.Name } |
        Sort-Object -Unique
)

$Drives = @()
foreach ($LocalDriveRoot in @($LocalCandidateDriveRoots)) {
    if (Test-Path -LiteralPath $LocalDriveRoot) {
        $Drives += $LocalDriveRoot
    } else {
        Add-Line ("Skipping unavailable local/removable drive: {0}" -f $LocalDriveRoot)
    }
}

if ($NetworkDriveRoots.Count -gt 0) {
    foreach ($NetworkDriveRoot in @($NetworkDriveRoots)) {
        Add-Line ("Skipping mapped network drive: {0}" -f $NetworkDriveRoot)
    }
} else {
    Add-Line 'No mapped network drives were detected.'
}

if ($Drives.Count -eq 0) {
    Add-Line 'No readable local fixed or removable drives were detected.'
}

$CohPathMap = @{}
$LegacyPathMap = @{}

foreach ($DriveRoot in @($Drives)) {
    Add-Line ("Scanning local drive: {0}" -f $DriveRoot)

    # One traversal catches both the modern Relaunch folder names and the old exact "Company of Heroes" folder name.
    $FoundOnDrive = @(
        Get-ChildItem -LiteralPath $DriveRoot `
            -Directory `
            -Filter 'Company of Heroes*' `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    )

    $FoundOnDrive = @(
        $FoundOnDrive |
            Where-Object { $_ -and $_.FullName } |
            Sort-Object FullName -Unique
    )

    $RelaunchFoundOnDrive = @(
        $FoundOnDrive |
            Where-Object { $_.Name -like 'Company of Heroes Relaunch*' }
    )

    $LegacyFoundOnDrive = @(
        $FoundOnDrive |
            Where-Object { $_.Name -eq 'Company of Heroes' }
    )

    Add-Line ("  Relaunch folder matches found: {0}" -f $RelaunchFoundOnDrive.Count)
    Add-Line ("  Legacy-name folder matches found: {0}" -f $LegacyFoundOnDrive.Count)

    foreach ($FoundFolder in @($RelaunchFoundOnDrive)) {
        $CohPathMap[$FoundFolder.FullName] = $FoundFolder.FullName
    }

    foreach ($FoundFolder in @($LegacyFoundOnDrive)) {
        $LegacyPathMap[$FoundFolder.FullName] = $FoundFolder.FullName
    }
}

$CohPaths = @($CohPathMap.Keys | Sort-Object)
$LegacyPaths = @($LegacyPathMap.Keys | Sort-Object)
$ActiveGamePaths = @(
    $CohPaths |
        Where-Object {
            (Get-CohFolderRole -Path $_) -eq 'ACTIVE_GAME'
        }
)
$BackupGamePaths = @(
    $CohPaths |
        Where-Object {
            (Get-CohFolderRole -Path $_) -eq 'BACKUP_GAME'
        }
)

$LegacyGamePaths = @(
    $LegacyPaths |
        Where-Object {
            (Get-LegacyFolderRole -Path $_) -eq 'LEGACY_GAME'
        }
)

$LegacyUserDataPaths = @(
    $LegacyPaths |
        Where-Object {
            (Get-LegacyFolderRole -Path $_) -eq 'LEGACY_USER_DATA'
        }
)

$LegacyFolderOnlyPaths = @(
    $LegacyPaths |
        Where-Object {
            (Get-LegacyFolderRole -Path $_) -eq 'LEGACY_FOLDER_ONLY'
        }
)

Add-Section 'Company of Heroes Relaunch folders found'
if ($CohPaths.Count -eq 0) {
    Add-Line 'No folders matching "Company of Heroes Relaunch*" were found on the scanned drives.'
} else {
    foreach ($CohPath in @($CohPaths)) {
        $FolderRole = Get-CohFolderRole -Path $CohPath

        Add-Line ("Folder: {0}" -f $CohPath)
        switch ($FolderRole) {
            'ACTIVE_GAME' {
                Add-Line 'Folder type: ACTIVE REAL GAME FOLDER - RelicCOH.exe found.'
            }
            'BACKUP_GAME' {
                Add-Line 'Folder type: BACKUP/MANUAL GAME COPY - RelicCOH.exe found, but the folder name looks like a backup copy.'
            }
            'USER_DATA' {
                Add-Line 'Folder type: USER DATA FOLDER - saves, config, logs, or Steam cloud data. No RelicCOH.exe expected here.'
            }
            'BACKUP_OR_MANUAL' {
                Add-Line 'Folder type: BACKUP OR MANUAL COPY - no RelicCOH.exe found.'
            }
            default {
                Add-Line 'Folder type: No RelicCOH.exe found - possible Steam mod folder, misplaced mod folder, or duplicate folder.'
            }
        }

        $TopLevelItems = @(
            Get-ChildItem -LiteralPath $CohPath -Force -ErrorAction SilentlyContinue |
                Sort-Object @{Expression = 'PSIsContainer'; Descending = $true}, Name
        )

        if ($TopLevelItems.Count -eq 0) {
            Add-Line 'Top-level contents: No items listed, the folder is empty, or access was denied.'
        } else {
            Add-Line 'Top-level contents:'
            foreach ($Item in @($TopLevelItems)) {
                if ($Item.PSIsContainer) {
                    Add-Line ("  [DIR]  {0}" -f $Item.Name)
                } else {
                    Add-Line ("  [FILE] {0}" -f $Item.Name)
                }
            }
        }

        Add-Line ''
    }
}

Add-Section 'Legacy / old Company of Heroes folders found'
if ($LegacyPaths.Count -eq 0) {
    Add-Line 'No folders named exactly "Company of Heroes" were found on the scanned local drives.'
} else {
    foreach ($LegacyPath in @($LegacyPaths)) {
        $LegacyRole = Get-LegacyFolderRole -Path $LegacyPath

        Add-Line ("Folder: {0}" -f $LegacyPath)
        switch ($LegacyRole) {
            'LEGACY_GAME' {
                Add-Line 'Folder type: LEGACY/OLD GAME INSTALL CANDIDATE - RelicCOH.exe found.'
            }
            'LEGACY_USER_DATA' {
                Add-Line 'Folder type: LEGACY/OLD USER DATA FOLDER - saves, config, logs, or older game data. No RelicCOH.exe expected here.'
            }
            default {
                Add-Line 'Folder type: Folder named "Company of Heroes" without RelicCOH.exe. Could be a partial install, manual copy, or non-game folder.'
            }
        }

        $LegacyTopLevelItems = @(
            Get-ChildItem -LiteralPath $LegacyPath -Force -ErrorAction SilentlyContinue |
                Sort-Object @{Expression = 'PSIsContainer'; Descending = $true}, Name
        )

        if ($LegacyTopLevelItems.Count -eq 0) {
            Add-Line 'Top-level contents: No items listed, the folder is empty, or access was denied.'
        } else {
            Add-Line 'Top-level contents:'
            foreach ($Item in @($LegacyTopLevelItems)) {
                if ($Item.PSIsContainer) {
                    Add-Line ("  [DIR]  {0}" -f $Item.Name)
                } else {
                    Add-Line ("  [FILE] {0}" -f $Item.Name)
                }
            }
        }

        Add-Line ''
    }
}

Add-Section 'Legacy / old Company of Heroes install check'
if ($LegacyPaths.Count -eq 0) {
    Add-Line 'Status: NOT FOUND'
    Add-Line 'No exact "Company of Heroes" folder was found on the scanned local drives.'
} else {
    Add-Line 'Status: FOUND'
    Add-Line ("Exact folder-name match(es) found: {0}" -f $LegacyPaths.Count)
    Add-Line ("Legacy/old game folder candidate(s) with RelicCOH.exe: {0}" -f $LegacyGamePaths.Count)
    Add-Line ("Legacy/old user data folder(s): {0}" -f $LegacyUserDataPaths.Count)
    Add-Line ("Other exact Company of Heroes folder(s) without RelicCOH.exe: {0}" -f $LegacyFolderOnlyPaths.Count)

    if ($LegacyGamePaths.Count -gt 0) {
        Add-Line ''
        Add-Line 'Legacy/old game folder candidate path(s):'
        foreach ($LegacyGamePath in @($LegacyGamePaths)) {
            Add-Line ("  {0}" -f $LegacyGamePath)
        }
    }

    Add-Line ''
    Add-Line 'Troubleshooting note:'
    Add-Line '  - This section is separate from the modern Company of Heroes Relaunch check.'
    Add-Line '  - If support users are looking in a folder named "Company of Heroes" instead of "Company of Heroes Relaunch", this can explain path confusion.'
    Add-Line '  - The launcher and Relaunch mod-placement checks continue to use "Company of Heroes Relaunch" as the active target.'
}

Add-Section 'Active Company of Heroes game folder check'
if ($ActiveGamePaths.Count -eq 0) {
    Add-Line 'Status: NOT FOUND'
    Add-Line 'No active main "Company of Heroes Relaunch" folder with RelicCOH.exe was found.'
    Add-Line 'This usually means the actual CoH game folder was not found, is not installed in a standard folder name, or access to the folder was unavailable.'
} elseif ($ActiveGamePaths.Count -eq 1) {
    Add-Line 'Status: FOUND'
    Add-Line ("Active real game folder: {0}" -f $ActiveGamePaths[0])
} else {
    Add-Line 'Status: MULTIPLE ACTIVE REAL GAME FOLDERS FOUND'
    Add-Line 'More than one active-looking scanned folder contained RelicCOH.exe:'
    foreach ($ActiveGamePath in @($ActiveGamePaths)) {
        Add-Line ("  {0}" -f $ActiveGamePath)
    }
    Add-Line 'This can cause confusion if mods are installed into one folder while the launcher or Steam uses another.'
}

if ($BackupGamePaths.Count -gt 0) {
    Add-Line ''
    Add-Line 'Backup/manual game copy folder(s) with RelicCOH.exe also found:'
    foreach ($BackupGamePath in @($BackupGamePaths)) {
        Add-Line ("  {0}" -f $BackupGamePath)
    }
    Add-Line 'These are reported separately and are not treated as the active main game folder.'
}

Add-Section 'Detected .module files inside scanned CoH Relaunch folders'
if ($CohPaths.Count -eq 0) {
    Add-Line 'No CoH Relaunch folders were available for .module file inspection.'
} else {
    foreach ($CohPath in @($CohPaths)) {
        Add-Line ("Folder: {0}" -f $CohPath)
        $ModuleFiles = @(
            Get-ChildItem -LiteralPath $CohPath -File -Filter '*.module' -Force -ErrorAction SilentlyContinue |
                Sort-Object Name
        )

        if ($ModuleFiles.Count -eq 0) {
            Add-Line '  No .module files found.'
        } else {
            foreach ($ModuleFile in @($ModuleFiles)) {
                Add-Line ("  {0}" -f $ModuleFile.Name)
            }
        }
    }
}

$SupportedMods = @(
    [pscustomobject]@{
        Name    = 'Eastern Front'
        Modules = @('Eastern_Front.module', 'EasternFront.module', 'Eastern Front.module')
        Folders = @('Eastern_Front', 'EasternFront', 'Eastern Front')
    },
    [pscustomobject]@{
        Name    = 'Modern Combat'
        Modules = @('ModernCombat.module')
        Folders = @('ModernCombat')
    },
    [pscustomobject]@{
        Name    = 'Blitzkrieg'
        Modules = @('Blitzkrieg.module')
        Folders = @('Blitzkrieg')
    },
    [pscustomobject]@{
        Name    = 'Europe in Ruins'
        Modules = @('EuropeInRuins.module')
        Folders = @('EuropeInRuins')
    },
    [pscustomobject]@{
        Name    = 'Europe at War'
        Modules = @('Europe_At_War.module', 'EuropeAtWar.module')
        Folders = @('Europe_At_War', 'EuropeAtWar')
    },
    [pscustomobject]@{
        Name    = 'Back to Basics'
        Modules = @('BackToBasics.module')
        Folders = @('BackToBasics')
    },
    [pscustomobject]@{
        Name    = 'Far East War / Far East Mod'
        Modules = @('Far_East_Mod.module')
        Folders = @('Far_East_Mod')
    },
    [pscustomobject]@{
        Name    = 'NHCmod'
        Modules = @('NHCToV.module', 'NHCmod.module')
        Folders = @('NHCToV', 'NHCmod')
    },
    [pscustomobject]@{
        Name    = 'The Great War'
        Modules = @('tgw.module')
        Folders = @('tgw')
    }
)

$SummaryEntries = @()

Add-Section 'Supported mod installation check'
foreach ($Mod in @($SupportedMods)) {
    $Findings = @(Get-ModFindings -Mod $Mod -CohPaths $CohPaths)
    $CorrectFindings = @($Findings | Where-Object { $_.Complete -and $_.Role -eq 'ACTIVE_GAME' })
    $BackupFindings = @($Findings | Where-Object { $_.Complete -and ($_.Role -eq 'BACKUP_GAME' -or $_.Role -eq 'BACKUP_OR_MANUAL') })
    $MisplacedFindings = @($Findings | Where-Object { $_.Complete -and $_.Role -eq 'OTHER' })
    $PartialFindings = @($Findings | Where-Object { -not $_.Complete })

    if ($CorrectFindings.Count -gt 0) {
        $Status = 'CORRECTLY INSTALLED'
    } elseif ($MisplacedFindings.Count -gt 0) {
        $Status = 'MISPLACED OR OUTSIDE THE ACTIVE GAME FOLDER'
    } elseif ($BackupFindings.Count -gt 0) {
        $Status = 'FOUND ONLY IN BACKUP OR MANUAL COPY'
    } elseif ($PartialFindings.Count -gt 0) {
        $Status = 'PARTIAL OR INCOMPLETE'
    } else {
        $Status = 'NOT FOUND'
    }

    $SummaryEntries += [pscustomobject]@{
        Mod    = $Mod.Name
        Status = $Status
    }

    Add-Line ("[{0}]" -f $Mod.Name)
    Add-Line ("Status: {0}" -f $Status)
    Add-Line ("Expected module candidate(s): {0}" -f (Format-Values -Values $Mod.Modules))
    Add-Line ("Expected mod folder candidate(s): {0}" -f (Format-Values -Values $Mod.Folders))

    if ($Findings.Count -eq 0) {
        Add-Line 'Detected files: No matching module files or mod folders were found in the scanned CoH Relaunch folders.'
    } else {
        Add-Line 'Detected files:'
        foreach ($Finding in @($Findings)) {
            Add-Line ("  Location: {0}" -f $Finding.Path)
            Add-Line ("    Folder role: {0}" -f (Get-CohFolderRoleLabel -Role $Finding.Role))
            Add-Line ("    Module file(s): {0}" -f (Format-Values -Values $Finding.Modules))
            Add-Line ("    Mod folder(s): {0}" -f (Format-Values -Values $Finding.Folders))
            if ($Finding.Complete) {
                Add-Line '    Pair check: COMPLETE - a module file and a mod folder were found together.'
            } else {
                Add-Line '    Pair check: INCOMPLETE - the module file or the mod folder is missing in this location.'
            }
        }
    }

    if ($CorrectFindings.Count -gt 0 -and ($MisplacedFindings.Count -gt 0 -or $BackupFindings.Count -gt 0)) {
        Add-Line 'Extra note: A correct active installation was found, but an additional complete copy also exists outside the active game folder.'
    } elseif ($MisplacedFindings.Count -gt 0 -and $BackupFindings.Count -gt 0) {
        Add-Line 'Extra note: Complete copies were found both in a backup/manual location and in a misplaced non-active folder.'
    }

    switch ($Status) {
        'CORRECTLY INSTALLED' {
            Add-Line 'Suggested action: No obvious active-installation issue was detected for this mod.'
        }
        'MISPLACED OR OUTSIDE THE ACTIVE GAME FOLDER' {
            Add-Line 'Suggested action: The mod appears to exist outside the active game folder. Use the matching repair/fix option in Kron4n CoH All-In-One Launcher if available.'
        }
        'FOUND ONLY IN BACKUP OR MANUAL COPY' {
            Add-Line 'Suggested action: A complete copy was found only in a backup/manual location, not in the active main game folder. This does not confirm the active CoH installation can launch this mod.'
        }
        'PARTIAL OR INCOMPLETE' {
            Add-Line 'Suggested action: The mod files look incomplete or split. Reinstall the mod, verify its files, or use the matching repair/fix option in the launcher if available.'
        }
        default {
            Add-Line 'Suggested action: No matching files were detected. This is fine if the mod is not installed.'
        }
    }

    Add-Line ''
}

Add-Section 'Diagnostic summary'
Add-Line ("Company of Heroes Relaunch folder(s) found: {0}" -f $CohPaths.Count)
Add-Line ("Active real CoH game folder(s) with RelicCOH.exe: {0}" -f $ActiveGamePaths.Count)
Add-Line ("Backup/manual game copy folder(s) with RelicCOH.exe: {0}" -f $BackupGamePaths.Count)
Add-Line ("Exact old/legacy Company of Heroes folder(s) found: {0}" -f $LegacyPaths.Count)
Add-Line ("Legacy/old game folder candidate(s) with RelicCOH.exe: {0}" -f $LegacyGamePaths.Count)
Add-Line ''
Add-Line 'Supported mod result summary:'
foreach ($Entry in @($SummaryEntries)) {
    Add-Line ("  - {0}: {1}" -f $Entry.Mod, $Entry.Status)
}

$MisplacedMods = @($SummaryEntries | Where-Object { $_.Status -eq 'MISPLACED OR OUTSIDE THE ACTIVE GAME FOLDER' })
$BackupOnlyMods = @($SummaryEntries | Where-Object { $_.Status -eq 'FOUND ONLY IN BACKUP OR MANUAL COPY' })
$PartialMods = @($SummaryEntries | Where-Object { $_.Status -eq 'PARTIAL OR INCOMPLETE' })

Add-Line ''
Add-Line 'Most important warnings:'
if ($ActiveGamePaths.Count -eq 0) {
    Add-Line '  - No active Company of Heroes game folder with RelicCOH.exe was found.'
}
if ($ActiveGamePaths.Count -gt 1) {
    Add-Line '  - Multiple active real CoH game folders were found. Make sure mods and launcher settings point to the intended one.'
}
if ($BackupGamePaths.Count -gt 0) {
    Add-Line '  - Backup/manual CoH game copy folder(s) with RelicCOH.exe were found and reported separately.'
}
if ($LegacyGamePaths.Count -gt 0) {
    Add-Line '  - Legacy/old Company of Heroes game folder candidate(s) with RelicCOH.exe were found and reported in a separate section.'
}
if ($MisplacedMods.Count -gt 0) {
    Add-Line ("  - Misplaced complete mod installation(s) detected: {0}" -f (($MisplacedMods | Select-Object -ExpandProperty Mod) -join ', '))
}
if ($BackupOnlyMods.Count -gt 0) {
    Add-Line ("  - Mod(s) found only in backup/manual copy locations: {0}" -f (($BackupOnlyMods | Select-Object -ExpandProperty Mod) -join ', '))
}
if ($PartialMods.Count -gt 0) {
    Add-Line ("  - Partial or incomplete mod installation(s) detected: {0}" -f (($PartialMods | Select-Object -ExpandProperty Mod) -join ', '))
}
if ($ActiveGamePaths.Count -gt 0 -and $MisplacedMods.Count -eq 0 -and $BackupOnlyMods.Count -eq 0 -and $PartialMods.Count -eq 0) {
    Add-Line '  - No major supported-mod placement problem was detected by this diagnostic scan.'
}

Add-Line ''
Add-Line 'Support note:'
Add-Line 'If the launcher or a mod still does not work, share this log file when asking for help:'
Add-Line ("  {0}" -f $script:LogPath)

Add-Line ''
Add-Line 'Diagnostic scan finished.'
Add-Line ("Log saved to: {0}" -f $script:LogPath)

Write-Host ''
[void](Read-Host 'Press Enter to close this window')
exit 0
