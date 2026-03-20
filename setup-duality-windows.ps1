# --- 1. User Input ---
Write-Host "--- Antigravity: Git & SSH Identity Setup (Windows/PowerShell) ---" -ForegroundColor Cyan
$personalEmail = Read-Host "Enter your Personal Email"
$workEmail = Read-Host "Enter your Work Email"
$repoRoot = Read-Host "Enter base repo directory (default: C:\repo)"
if (-not $repoRoot) { $repoRoot = "C:\repo" }

# --- 2. Directory & Service Setup ---
New-Item -Path "$repoRoot\personal", "$repoRoot\work" -ItemType Directory -Force | Out-Null
$sshDir = "$HOME\.ssh"
if (-not (Test-Path $sshDir)) { New-Item -Path $sshDir -ItemType Directory }

Write-Host "Ensuring SSH Agent Service is running..." -ForegroundColor Yellow
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent -ErrorAction SilentlyContinue

# --- 3. SSH Key Generation ---
function Setup-Key {
    param($path, $email)
    if (-not (Test-Path $path)) {
        Write-Host "Generating key for $email..." -ForegroundColor Green
        ssh-keygen -t ed25519 -C $email -f $path -N '""'
    } else {
        Write-Host "Existing key found at $path. Skipping." -ForegroundColor Gray
    }
}

Setup-Key "$sshDir\id_ed25519" $personalEmail
Setup-Key "$sshDir\id_ed25519_work" $workEmail

# --- 4. SSH & Git Config Generation ---
$sshConfig = @"
# --- Antigravity Config Start ---
Host github.com-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

Host github.com-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work
    IdentitiesOnly yes
# --- Antigravity Config End ---
"@
Add-Content "$sshDir\config" $sshConfig

# Create Git Sub-Configs
@'
[user]
    email = {0}
[url "git@github.com-personal:"]
    insteadOf = git@github.com:
'@ -f $personalEmail | Set-Content "$HOME\.gitconfig-personal"

@'
[user]
    email = {0}
[url "git@github.com-work:"]
    insteadOf = git@github.com:
'@ -f $workEmail | Set-Content "$HOME\.gitconfig-work"

# Apply Global includeIf (Replace backslashes with forward slashes for Git)
$gitRoot = $repoRoot.Replace('\', '/')
git config --global includeIf."gitdir:$gitRoot/personal/".path "~/.gitconfig-personal"
git config --global includeIf."gitdir:$gitRoot/work/".path "~/.gitconfig-work"

# --- 5. Profile Update ---
$profileExtras = @"
`$env:SSH_AUTH_SOCK = "\\.\pipe\openssh-ssh-agent"

function clone-work {
    param([string]`$url, [string]`$folderName)
    if (-not `$folderName) { `$folderName = (`$url -split '/' | Select-Object -Last 1) -replace '\.git$', '' }
    `$workUrl = `$url -replace "github.com:", "github.com-work:"
    git clone `$workUrl "$repoRoot\work\`$folderName"
}

function clone-personal {
    param([string]`$url, [string]`$folderName)
    if (-not `$folderName) { `$folderName = (`$url -split '/' | Select-Object -Last 1) -replace '\.git$', '' }
    `$persUrl = `$url -replace "github.com:", "github.com-personal:"
    git clone `$persUrl "$repoRoot\personal\`$folderName"
}
"@

if (-not (Test-Path $PROFILE)) { New-Item -Path $PROFILE -Type File -Force }
Add-Content $PROFILE "`n$profileExtras"

Write-Host "--- Setup Complete! ---" -ForegroundColor Cyan
Write-Host "1. Restart PowerShell or run: . `$PROFILE"
Write-Host "2. Add your .pub keys to GitHub (Personal: id_ed25519.pub, Work: id_ed25519_work.pub)"
