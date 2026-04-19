#Requires -Version 5.1
<#
.SYNOPSIS
    PR Comment Fix Skill - PowerShell Installer
.DESCRIPTION
    Installs pr-comment-fix skill to Claude Code, Cursor, VSCode Copilot, or OpenCode on Windows.
.PARAMETER Target
    Installation target: claude, cursor, vscode, opencode, local, all, uninstall
.PARAMETER Auto
    Auto-detect platform and install
.EXAMPLE
    .\install.ps1 -Auto
    .\install.ps1 -Target claude
    .\install.ps1 -Target all
#>
param(
    [ValidateSet('claude', 'cursor', 'vscode', 'opencode', 'local', 'all', 'uninstall')]
    [string]$Target,
    [switch]$Auto
)

$SkillName = "pr-comment-fix"
$SkillDir = $PSScriptRoot

function Write-Header {
    Write-Host ""
    Write-Host "  PR Comment Fix Skill - Installer" -ForegroundColor Cyan
    Write-Host "  =================================" -ForegroundColor Cyan
    Write-Host ""
}

function Install-ToDir {
    param(
        [string]$TargetDir,
        [string]$PlatformName,
        [switch]$Full
    )

    Write-Host "Installing to $PlatformName..." -ForegroundColor Blue

    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    }

    # Always copy SKILL.md
    Copy-Item -Path "$SkillDir\SKILL.md" -Destination $TargetDir -Force

    if ($Full) {
        # Copy agents, scripts, references, lib
        $dirs = @('agents', 'scripts', 'references')
        foreach ($d in $dirs) {
            $src = Join-Path $SkillDir $d
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $TargetDir -Recurse -Force
            }
        }
        # Copy lib from skills/pr-comment-fix/lib if exists
        $libSrc = Join-Path $SkillDir "skills\pr-comment-fix\lib"
        if (Test-Path $libSrc) {
            $libDst = Join-Path $TargetDir "lib"
            Copy-Item -Path $libSrc -Destination $libDst -Recurse -Force
        }
        # Also copy lib from root lib/ if exists
        $rootLibSrc = Join-Path $SkillDir "lib"
        if (Test-Path $rootLibSrc) {
            Copy-Item -Path $rootLibSrc -Destination $TargetDir -Recurse -Force
        }
    }

    Write-Host "  Installed to: $TargetDir" -ForegroundColor Green
}

function Install-ClaudeCode {
    $target = Join-Path $HOME ".claude\skills\$SkillName"
    Install-ToDir -TargetDir $target -PlatformName "Claude Code" -Full
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host "    /skill load pr-comment-fix"
    Write-Host "    Or ask: 'Help me fix PR comments'"
}

function Install-Cursor {
    $target = Join-Path $HOME ".cursor\skills\$SkillName"
    Install-ToDir -TargetDir $target -PlatformName "Cursor"
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host "    Add @pr-comment-fix in chat"
}

function Install-VSCode {
    $target = Join-Path $HOME ".vscode\copilot\skills\$SkillName"
    Install-ToDir -TargetDir $target -PlatformName "VSCode Copilot"
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host "    Use in Copilot chat: @pr-comment-fix"
}

function Install-OpenCode {
    $target = Join-Path $HOME ".opencode\skills\$SkillName"
    Install-ToDir -TargetDir $target -PlatformName "OpenCode" -Full
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host "    /skill load pr-comment-fix"
}

function Install-Local {
    $target = Join-Path (Get-Location) ".claude\skills\$SkillName"
    Install-ToDir -TargetDir $target -PlatformName "Local Project" -Full
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host "    Skill will auto-load for this project"
}

function Uninstall-All {
    Write-Host "Uninstalling..." -ForegroundColor Yellow
    $paths = @(
        (Join-Path $HOME ".claude\skills\$SkillName"),
        (Join-Path $HOME ".cursor\skills\$SkillName"),
        (Join-Path $HOME ".vscode\copilot\skills\$SkillName"),
        (Join-Path $HOME ".opencode\skills\$SkillName"),
        (Join-Path (Get-Location) ".claude\skills\$SkillName")
    )
    foreach ($p in $paths) {
        if (Test-Path $p) {
            Remove-Item -Recurse -Force $p
            Write-Host "  Removed: $p" -ForegroundColor Green
        }
    }
    Write-Host "  Uninstalled from all platforms" -ForegroundColor Green
}

function Detect-Platform {
    if (Test-Path (Join-Path $HOME ".claude")) { return "claude" }
    if (Test-Path (Join-Path $HOME ".cursor")) { return "cursor" }
    if (Test-Path (Join-Path $HOME ".vscode")) { return "vscode" }
    if (Get-Command opencode -ErrorAction SilentlyContinue) { return "opencode" }
    return "local"
}

# Main
Write-Header

if ($Auto) {
    $detected = Detect-Platform
    Write-Host "Auto-detected platform: $detected" -ForegroundColor Blue
    Write-Host ""
    $Target = $detected
}

if (-not $Target) {
    Write-Host "Select installation target:"
    Write-Host ""
    Write-Host "  1) Claude Code (global)"
    Write-Host "  2) Cursor (global)"
    Write-Host "  3) VSCode Copilot (global)"
    Write-Host "  4) OpenCode (global)"
    Write-Host "  5) Local project"
    Write-Host "  6) All supported platforms"
    Write-Host "  7) Uninstall"
    Write-Host ""
    $choice = Read-Host "Enter choice [1-7]"

    switch ($choice) {
        '1' { $Target = 'claude' }
        '2' { $Target = 'cursor' }
        '3' { $Target = 'vscode' }
        '4' { $Target = 'opencode' }
        '5' { $Target = 'local' }
        '6' { $Target = 'all' }
        '7' { $Target = 'uninstall' }
        default {
            Write-Host "Invalid choice" -ForegroundColor Red
            exit 1
        }
    }
}

switch ($Target) {
    'claude'    { Install-ClaudeCode }
    'cursor'    { Install-Cursor }
    'vscode'    { Install-VSCode }
    'opencode'  { Install-OpenCode }
    'local'     { Install-Local }
    'all'       {
        Install-ClaudeCode
        Install-Cursor
        Install-VSCode
        Install-OpenCode
        Write-Host ""
        Write-Host "  All platforms installed successfully!" -ForegroundColor Green
    }
    'uninstall' { Uninstall-All }
}

Write-Host ""
