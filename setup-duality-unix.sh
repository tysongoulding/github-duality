#!/bin/bash

# --- 1. Interactive Input ---
echo "--- Antigravity: Git & SSH Identity Setup (Linux/macOS) ---"
read -p "Enter your Personal Email: " PERSONAL_EMAIL
read -p "Enter your Work Email: " WORK_EMAIL
read -p "Enter base repo directory (default: $HOME/repo): " REPO_ROOT
REPO_ROOT=${REPO_ROOT:-$HOME/repo}

read -p "Enter Work Organizations (space-separated, e.g., company organization): " WORK_ORGS
read -p "Enter Work Domains (space-separated, e.g., gitlab.company.com): " WORK_DOMAINS
read -p "Enter Personal Organizations (space-separated, e.g., username): " PERSONAL_ORGS
read -p "Enter Personal Domains (space-separated, e.g., github.com): " PERSONAL_DOMAINS

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
# Only add SSH config if not already present
if [ -f "$HOME/.ssh/config" ] && grep -q "# --- Antigravity Config Start ---" "$HOME/.ssh/config"; then
    echo "SSH config already updated. Skipping."
else
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
fi

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

# Write Global Duality Settings
git config --global duality.personalEmail "$PERSONAL_EMAIL"
git config --global duality.workEmail "$WORK_EMAIL"
git config --global duality.personalKey "~/.ssh/id_ed25519"
git config --global duality.workKey "~/.ssh/id_ed25519_work"
git config --global duality.workOrgs "$WORK_ORGS"
git config --global duality.personalOrgs "$PERSONAL_ORGS"
git config --global duality.workDomains "$WORK_DOMAINS"
git config --global duality.personalDomains "$PERSONAL_DOMAINS"
git config --global duality.workDir "$REPO_ROOT/work"
git config --global duality.personalDir "$REPO_ROOT/personal"
git config --global duality.defaultIdentity "personal"

# --- 5. Global Hooks & Templates Setup ---
DUALITY_DIR="$HOME/.git-duality"
mkdir -p "$DUALITY_DIR/templates/hooks"

# Copy duality-hook.sh and make it executable
cp duality-hook.sh "$DUALITY_DIR/duality-hook.sh"
chmod +x "$DUALITY_DIR/duality-hook.sh"

# Write Hook Stubs to the template directory
cat <<'EOF' > "$DUALITY_DIR/templates/hooks/post-checkout"
#!/bin/sh
"$HOME/.git-duality/duality-hook.sh" "$@"
EOF

cat <<'EOF' > "$DUALITY_DIR/templates/hooks/pre-commit"
#!/bin/sh
"$HOME/.git-duality/duality-hook.sh" "$@"
EOF

cat <<'EOF' > "$DUALITY_DIR/templates/hooks/pre-push"
#!/bin/sh
"$HOME/.git-duality/duality-hook.sh" "$@"
EOF

chmod +x "$DUALITY_DIR/templates/hooks/post-checkout" "$DUALITY_DIR/templates/hooks/pre-commit" "$DUALITY_DIR/templates/hooks/pre-push"

# Configure Global Git Template Directory
git config --global init.templateDir "$DUALITY_DIR/templates"

# --- 6. Profile Injection ---
# Detect shell (bash or zsh)
if [[ "$SHELL" == *"zsh"* ]]; then
    PROFILE="$HOME/.zshrc"
else
    PROFILE="$HOME/.bashrc"
fi

echo "Adding helpers to $PROFILE..."

# Only append if not already there
if grep -q "function git-duality" "$PROFILE" 2>/dev/null; then
    echo "Helpers already present in $PROFILE. Skipping profile update."
else
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

function git-duality() {
    local identity=\$1
    if [[ -n "\$identity" ]]; then
        if [[ "\$identity" == "work" ]]; then
            git config user.email "\$(git config --global duality.workEmail)"
            local work_key=\$(git config --global duality.workKey)
            work_key=\${work_key:-~/.ssh/id_ed25519_work}
            work_key=\${work_key/#\~/\$HOME}
            git config core.sshCommand "ssh -i \"\$work_key\" -o IdentitiesOnly=yes"
            echo "Manually configured repository for Work."
        elif [[ "\$identity" == "personal" ]]; then
            git config user.email "\$(git config --global duality.personalEmail)"
            local pers_key=\$(git config --global duality.personalKey)
            pers_key=\${pers_key:-~/.ssh/id_ed25519}
            pers_key=\${pers_key/#\~/\$HOME}
            git config core.sshCommand "ssh -i \"\$pers_key\" -o IdentitiesOnly=yes"
            echo "Manually configured repository for Personal."
        else
            echo "Error: Invalid identity. Use 'work' or 'personal'." >&2
            return 1
        fi
    else
        echo "Running Duality auto-detection..."
        if [[ -d ".git" ]]; then
            local hooks_dir=".git/hooks"
            mkdir -p "\$hooks_dir"
            cat <<'INNER_EOF' > "\$hooks_dir/post-checkout"
#!/bin/sh
"\$HOME/.git-duality/duality-hook.sh" "\$@"
INNER_EOF
            cat <<'INNER_EOF' > "\$hooks_dir/pre-commit"
#!/bin/sh
"\$HOME/.git-duality/duality-hook.sh" "\$@"
INNER_EOF
            cat <<'INNER_EOF' > "\$hooks_dir/pre-push"
#!/bin/sh
"\$HOME/.git-duality/duality-hook.sh" "\$@"
INNER_EOF
            chmod +x "\$hooks_dir/post-checkout" "\$hooks_dir/pre-commit" "\$hooks_dir/pre-push"
            echo "Installed Duality hooks in current repository."
            if command -v bash >/dev/null; then
                bash "\$HOME/.git-duality/duality-hook.sh"
            elif command -v sh >/dev/null; then
                sh "\$HOME/.git-duality/duality-hook.sh"
            else
                echo "Hooks installed, but could not execute bash/sh for immediate run. It will run automatically on git actions."
            fi
        else
            echo "Error: Not a git repository. Run this command inside a git repository." >&2
            return 1
        fi
    fi
}
EOF
fi

echo "--- Setup Complete! ---"
echo "1. Run: source $PROFILE"
echo "2. Add your .pub keys to GitHub (Personal: id_ed25519.pub, Work: id_ed25519_work.pub)"
