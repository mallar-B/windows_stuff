Import-Module PSReadLine

# Syntax highlighting / autosuggestions
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView

# Vim editing mode
Set-PSReadLineOption -EditMode Vi


Set-PSReadLineKeyHandler -Chord Ctrl+p -Function HistorySearchBackward # Ctrl-P -> history search backward
Set-PSReadLineKeyHandler -Chord Ctrl+n -Function HistorySearchForward # Ctrl-N -> history search forward
# Ctrl-Y -> accept autosuggestion
Set-PSReadLineKeyHandler -Chord Ctrl+y -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptSuggestion()
}


# History
Set-PSReadLineOption -MaximumHistoryCount 5000
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally

# Fuzzy history search(Ctrl-R)
function Invoke-FuzzyHistory {
    $line = $null
    $cursor = 0

    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState(
        [ref]$line,
        [ref]$cursor
    )

    # Everything typed before the cursor.
    $prefix = $line.Substring(0, $cursor)

    # Get PSReadLine history.
    $history = Get-Content (
        (Get-PSReadLineOption).HistorySavePath
    ) -ErrorAction SilentlyContinue

    if (-not $history) {
        return
    }

    if ([string]::IsNullOrEmpty($prefix)) {
        $selected = $history |
            fzf `
                --height 40% `
                --reverse
    }
    else {
        $selected = $history |
            Where-Object { $_.StartsWith($prefix) } |
            fzf `
                --height 40% `
                --reverse `
                --query="$prefix"
    }

    if ([string]::IsNullOrEmpty($selected)) {
        return
    }

    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
        0,
        $line.Length,
        $selected
    )
}

Set-PSReadLineKeyHandler `
    -Chord Ctrl+r `
    -ScriptBlock {
        Invoke-FuzzyHistory
    }


# zoxide
Invoke-Expression (& {
    zoxide init powershell | Out-String
})


# List aliases
function ls {
    Get-ChildItem
}

function la {
    Get-ChildItem -Force
}

function ll {
    Get-ChildItem -Force
}

function lx {
    Get-ChildItem |
        Sort-Object Extension
}

function lr {
    Get-ChildItem -Recurse
}

function lf {
    Get-ChildItem -File
}

function lz {
    Get-ChildItem |
        Sort-Object Length -Descending
}

function lt {
    Get-ChildItem |
        Sort-Object LastWriteTime -Descending
}

function llt {
    Get-ChildItem -Force |
        Sort-Object LastWriteTime -Descending
}

function ldir {
    Get-ChildItem -Directory
}


# Quality of life aliases
function poweroff {
    Stop-Computer
}

function reboot {
    Restart-Computer
}

# cd -> zoxide
function cd {
    param(
        [Parameter(ValueFromRemainingArguments)]
        $Path
    )

    z $Path
}

function cp {
    param(
        [Parameter(Mandatory)]
        $Path,

        [Parameter(Mandatory)]
        $Destination
    )

    Copy-Item -Path $Path -Destination $Destination -Confirm
}

function cpr {
    param(
        [Parameter(Mandatory)]
        $Path,

        [Parameter(Mandatory)]
        $Destination
    )

    Copy-Item `
        -Path $Path `
        -Destination $Destination `
        -Recurse `
        -Confirm
}

function mv {
    param(
        [Parameter(Mandatory)]
        $Path,

        [Parameter(Mandatory)]
        $Destination
    )

    Move-Item -Path $Path -Destination $Destination -Confirm
}


# rm -> Recycle Bin
Add-Type -AssemblyName Microsoft.VisualBasic

function rm {
    param(
        [Parameter(Mandatory, ValueFromRemainingArguments)]
        [string[]]$Path
    )

    foreach ($item in $Path) {
        if (Test-Path $item -PathType Container) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                (Resolve-Path $item).Path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
        }
        elseif (Test-Path $item) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                (Resolve-Path $item).Path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
        }
    }
}


function mkdir {
    param(
        [Parameter(Mandatory, ValueFromRemainingArguments)]
        [string[]]$Path
    )

    New-Item -ItemType Directory -Force -Path $Path
}

function cls {
    Clear-Host
}


# Directory aliases
function home {
    Set-Location $HOME
}

function cd.. {
    Set-Location ..
}

function .. {
    Set-Location ..
}

function ... {
    Set-Location ../..
}

function .... {
    Set-Location ../../..
}

function ..... {
    Set-Location ../../../..
}


# Git prompt
$PROMPT_USER_COLOR = "`e[36m"
$PROMPT_HOST_COLOR = "`e[34m"
$PROMPT_PATH_COLOR = "`e[32m"
$PROMPT_GIT_COLOR  = "`e[35m"
$PROMPT_ERROR_COLOR = "`e[31m"
$PROMPT_DIM_COLOR = "`e[38;5;244m"
$PROMPT_RESET = "`e[0m"


function Get-GitPrompt {
    $insideGit = git rev-parse --is-inside-work-tree 2>$null

    if ($insideGit -ne "true") {
        return ""
    }

    $branch = git branch --show-current 2>$null

    if ([string]::IsNullOrEmpty($branch)) {
        $branch = git rev-parse --short HEAD 2>$null
    }

    $result = "${PROMPT_GIT_COLOR}   $branch${PROMPT_RESET}"

    $status = @(git status --porcelain 2>$null)

    # --------------------------------------------------------
    # Ahead / Behind
    # --------------------------------------------------------

    $aheadBehind = git rev-list --left-right --count HEAD...'@{upstream}' 2>$null

    if ($aheadBehind) {
        $parts = $aheadBehind -split '\s+'

        if ($parts.Count -ge 2) {
            $ahead = [int]$parts[0]
            $behind = [int]$parts[1]

            if ($ahead -gt 0) {
                $result += " ${PROMPT_USER_COLOR}⇡${PROMPT_RESET}"
            }

            if ($behind -gt 0) {
                $result += " ${PROMPT_ERROR_COLOR}⇣${PROMPT_RESET}"
            }
        }
    }


    # --------------------------------------------------------
    # Conflicts
    # --------------------------------------------------------

    if ($status -match '^(UU|AA|DD|AU|UA|UD|DU)') {
        $result += " ${PROMPT_ERROR_COLOR}═${PROMPT_RESET}"
    }


    # --------------------------------------------------------
    # Staged
    # --------------------------------------------------------

    if ($status -match '^[MADRC] ') {
        $result += " ${PROMPT_USER_COLOR}+${PROMPT_RESET}"
    }


    # --------------------------------------------------------
    # Modified / unstaged
    # --------------------------------------------------------

    if ($status -match '^.[MTD]') {
        $result += " ${PROMPT_ERROR_COLOR}!${PROMPT_RESET}"
    }


    # --------------------------------------------------------
    # Renamed
    # --------------------------------------------------------

    if ($status -match '^R ') {
        $result += " ${PROMPT_USER_COLOR}»${PROMPT_RESET}"
    }


    # --------------------------------------------------------
    # Deleted
    # --------------------------------------------------------

    if ($status -match '^D |^.D') {
        $result += " ${PROMPT_ERROR_COLOR}✘${PROMPT_RESET}"
    }


    # --------------------------------------------------------
    # Untracked
    # --------------------------------------------------------

    if ($status -match '^\?\?') {
        $result += " ${PROMPT_DIM_COLOR}?${PROMPT_RESET}"
    }


    # --------------------------------------------------------
    # Stash
    # --------------------------------------------------------

    $stashCount = @(git stash list 2>$null).Count

    if ($stashCount -gt 0) {
        $result += " ${PROMPT_GIT_COLOR}`$${PROMPT_RESET}"
    }

    return $result
}


# Prompt
function prompt {

    $lastSuccess = $?

    $gitPrompt = Get-GitPrompt

    # Current path.
    $path = (Get-Location).Path

    # Replace home directory with ~.
    if ($path.StartsWith($HOME)) {
        $path = "~" + $path.Substring($HOME.Length)
    }

    # --------------------------------------------------------
    # Exit status
    # --------------------------------------------------------

    if (-not $lastSuccess) {
        $exitStatus = "${PROMPT_ERROR_COLOR}✘ 1${PROMPT_RESET}  "
        $symbol = "${PROMPT_ERROR_COLOR}❯${PROMPT_RESET}"
    }
    else {
        $exitStatus = ""
        $symbol = "${PROMPT_USER_COLOR}❯${PROMPT_RESET}"
    }

    # --------------------------------------------------------
    # SSH username / hostname
    # --------------------------------------------------------

    $userHost = ""

    if ($env:SSH_CONNECTION) {
        $userHost = "${PROMPT_DIM_COLOR}$env:USERNAME@$env:COMPUTERNAME${PROMPT_RESET}`n"
    }

    # --------------------------------------------------------
    # Two-line prompt
    # --------------------------------------------------------

    return "${userHost}${exitStatus}${PROMPT_PATH_COLOR}${path}${PROMPT_RESET}${gitPrompt}`n${symbol} "
}

# Terminal title
function Set-TerminalTitle {
    $Host.UI.RawUI.WindowTitle = "$env:USERNAME@$env:COMPUTERNAME`: $((Get-Location).Path)"
}

# Update title before each prompt.
$ExecutionContext.InvokeCommand.PreCommandLookupAction = {
    param($commandName, $commandLookupEventArgs)

    if ($commandName -eq "prompt") {
        Set-TerminalTitle
    }
}
