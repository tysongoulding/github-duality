#!/bin/bash

# --- 1. Interactive Input ---
echo "--- Antigravity: Git & SSH Identity Setup (Linux/macOS) ---"
read -p "Enter your Personal Email: " PERSONAL_EMAIL
read -p "Enter your Work Email: " WORK_EMAIL
read -p "Enter base repo directory (default: $HOME/repo): " REPO_ROOT
REPO_ROOT=${REPO_ROOT:-$HOME/repo}

# --- 2. Create Directory Structure ---
echo "Creating directory structure..."
mkdir -p "$REPO_ROOT/personal" "$REPO_ROOT/work"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# --- 3. SSH Key Generation ---
setup_key() {
    local key_path=$1
    local email=$2
    if [ ! -f "$key_path" ]; then
        echo "Generating key for $email..."
        ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""
    else
        echo "Existing key found at $key_path. Skipping."
    fi
}

setup_key "$HOME/.ssh/id_ed25519" "$PERSONAL_EMAIL"
setup_key "$HOME/.ssh/id_ed25519_work" "$WORK_EMAIL"

# --- 4. SSH & Git Config Generation ---
echo "Updating SSH config..."
cat <<EOF >> "$HOME/.ssh/config"

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
EOF
chmod 600 "$HOME/.ssh/config"

# Create Git Sub-Configs
cat <<EOF > "$HOME/.gitconfig-personal"
[user]
    email = $PERSONAL_EMAIL
[url "git@github.com-personal:"]
    insteadOf = git@github.com:
EOF

cat <<EOF > "$HOME/.gitconfig-work"
[user]
    email = $WORK_EMAIL
[url "git@github.com-work:"]
    insteadOf = git@github.com:
EOF

# Apply Global includeIf
git config --global includeIf."gitdir:$REPO_ROOT/personal/".path "~/.gitconfig-personal"
git config --global includeIf."gitdir:$REPO_ROOT/work/".path "~/.gitconfig-work"

# --- 5. Profile Injection ---
# Detect shell (bash or zsh)
if [[ "$SHELL" == *"zsh"* ]]; then
    PROFILE="$HOME/.zshrc"
else
    PROFILE="$HOME/.bashrc"
fi

echo "Adding helpers to $PROFILE..."
cat <<EOF >> "$PROFILE"

# Antigravity Clone Helpers
function clone-work() {
    local url=\$1
    local folder=\$2
    [[ -z "\$folder" ]] && folder=\$(basename "\$url" .git)
    local work_url=\${url/github.com:/github.com-work:}
    git clone "\$work_url" "$REPO_ROOT/work/\$folder"
}

function clone-personal() {
    local url=\$1
    local folder=\$2
    [[ -z "\$folder" ]] && folder=\$(basename "\$url" .git)
    local pers_url=\${url/github.com:/github.com-personal:}
    git clone "\$pers_url" "$REPO_ROOT/personal/\$folder"
}
EOF

echo "--- Setup Complete! ---"
echo "1. Run: source $PROFILE"
echo "2. Add your .pub keys to GitHub (Personal: id_ed25519.pub, Work: id_ed25519_work.pub)"
