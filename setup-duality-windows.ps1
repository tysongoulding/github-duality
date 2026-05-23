# --- 1. User Input ---
Write-Host "--- Antigravity: Git & SSH Identity Setup (Windows/PowerShell) ---" -ForegroundColor Cyan
$personalEmail = Read-Host "Enter your Personal Email"
$workEmail = Read-Host "Enter your Work Email"
$repoRoot = Read-Host "Enter base repo directory (default: C:\repo)"
if (-not $repoRoot) { $repoRoot = "C:\repo" }

$workOrgs = Read-Host "Enter Work Organizations (space-separated, e.g., company organization)"
$workDomains = Read-Host "Enter Work Domains (space-separated, e.g., gitlab.company.com)"
$personalOrgs = Read-Host "Enter Personal Organizations (space-separated, e.g., username)"
$personalDomains = Read-Host "Enter Personal Domains (space-separated, e.g., github.com)"

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
# Check if ssh config already contains config
$sshConfigPath = "$sshDir\config"
if (Test-Path $sshConfigPath) {
    $content = Get-Content $sshConfigPath -Raw
    if ($content -notlike "*# --- Antigravity Config Start ---*") {
        Add-Content $sshConfigPath "`n$sshConfig"
    }
} else {
    Set-Content $sshConfigPath $sshConfig
}

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

# Write Global Duality Settings
git config --global duality.personalEmail $personalEmail
git config --global duality.workEmail $workEmail
git config --global duality.personalKey "~/.ssh/id_ed25519"
git config --global duality.workKey "~/.ssh/id_ed25519_work"
git config --global duality.workOrgs $workOrgs
git config --global duality.personalOrgs $personalOrgs
git config --global duality.workDomains $workDomains
git config --global duality.personalDomains $personalDomains
git config --global duality.workDir "$repoRoot\work"
git config --global duality.personalDir "$repoRoot\personal"
git config --global duality.defaultIdentity "personal"

# --- 5. Global Hooks & Templates Setup ---
$dualityDir = "$HOME\.git-duality"
New-Item -Path $dualityDir -ItemType Directory -Force | Out-Null
New-Item -Path "$dualityDir\templates\hooks" -ItemType Directory -Force | Out-Null

# Copy duality-hook.sh to the global installation path
Copy-Item -Path "duality-hook.sh" -Destination "$dualityDir\duality-hook.sh" -Force

# Write Hook Stubs to the template directory
$stubContent = @"
#!/bin/sh
"`$HOME/.git-duality/duality-hook.sh" "`$@"
"@

Set-Content -Path "$dualityDir\templates\hooks\post-checkout" -Value $stubContent
Set-Content -Path "$dualityDir\templates\hooks\pre-commit" -Value $stubContent
Set-Content -Path "$dualityDir\templates\hooks\pre-push" -Value $stubContent

# Configure Global Git Template Directory
$templatePath = "$dualityDir\templates".Replace('\', '/')
git config --global init.templateDir "$templatePath"

# --- 6. Profile Update ---
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

function git-duality {
    param([string]`$identity)
    if (`$identity) {
        if (`$identity -eq "work") {
            git config user.email "$(git config --global duality.workEmail)"
            `$workKey = git config --global duality.workKey
            if (-not `$workKey) { `$workKey = "~/.ssh/id_ed25519_work" }
            `$workKeyResolved = `$workKey.Replace('~', `$env:USERPROFILE).Replace('\', '/')
            git config core.sshCommand "ssh -i `"`$workKeyResolved`" -o IdentitiesOnly=yes"
            Write-Host "Manually configured repository for Work." -ForegroundColor Green
        } elseif (`$identity -eq "personal") {
            git config user.email "$(git config --global duality.personalEmail)"
            `$persKey = git config --global duality.personalKey
            if (-not `$persKey) { `$persKey = "~/.ssh/id_ed25519" }
            `$persKeyResolved = `$persKey.Replace('~', `$env:USERPROFILE).Replace('\', '/')
            git config core.sshCommand "ssh -i `"`$persKeyResolved`" -o IdentitiesOnly=yes"
            Write-Host "Manually configured repository for Personal." -ForegroundColor Green
        } else {
            Write-Error "Invalid identity. Use 'work' or 'personal'."
        }
    } else {
        Write-Host "Running Duality auto-detection..." -ForegroundColor Yellow
        if (Test-Path ".git") {
            `$hooksDir = ".git\hooks"
            if (-not (Test-Path `$hooksDir)) { New-Item -Path `$hooksDir -ItemType Directory -Force | Out-Null }
            `$stub = @"
#!/bin/sh
"`\`$HOME/.git-duality/duality-hook.sh" "\`$@"
"@
            Set-Content -Path "`$hooksDir\post-checkout", "`$hooksDir\pre-commit", "`$hooksDir\pre-push" -Value `$stub
            Write-Host "Installed Duality hooks in current repository." -ForegroundColor Cyan
            if (Get-Command bash -ErrorAction SilentlyContinue) {
                bash -c "~/.git-duality/duality-hook.sh"
            } elseif (Get-Command sh -ErrorAction SilentlyContinue) {
                sh -c "~/.git-duality/duality-hook.sh"
            } else {
                Write-Host "Hooks installed, but could not execute bash/sh for immediate run. It will run automatically on git actions." -ForegroundColor Yellow
            }
        } else {
            Write-Error "Not a git repository. Run this command inside a git repository."
        }
    }
}
"@

if (-not (Test-Path $PROFILE)) { New-Item -Path $PROFILE -Type File -Force }
$profileContent = Get-Content $PROFILE -Raw
if ($profileContent -notlike "*function git-duality*") {
    Add-Content $PROFILE "`n$profileExtras"
}

Write-Host "--- Setup Complete! ---" -ForegroundColor Cyan
Write-Host "1. Restart PowerShell or run: . `$PROFILE"
Write-Host "2. Add your .pub keys to GitHub (Personal: id_ed25519.pub, Work: id_ed25519_work.pub)"
