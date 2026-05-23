#!/bin/sh

# Get global Git configs for Duality
PERSONAL_EMAIL=$(git config --global duality.personalEmail)
WORK_EMAIL=$(git config --global duality.workEmail)
PERSONAL_KEY=$(git config --global duality.personalKey)
WORK_KEY=$(git config --global duality.workKey)
WORK_ORGS=$(git config --global duality.workOrgs)
PERSONAL_ORGS=$(git config --global duality.personalOrgs)
WORK_DOMAINS=$(git config --global duality.workDomains)
PERSONAL_DOMAINS=$(git config --global duality.personalDomains)
WORK_DIR=$(git config --global duality.workDir)
PERSONAL_DIR=$(git config --global duality.personalDir)
DEFAULT_IDENTITY=$(git config --global duality.defaultIdentity)

# Fallbacks
: "${PERSONAL_KEY:=$HOME/.ssh/id_ed25519}"
: "${WORK_KEY:=$HOME/.ssh/id_ed25519_work}"
: "${DEFAULT_IDENTITY:=personal}"

# Function to check if target domain matches domain patterns in list
match_domain() {
    target=$1
    list=$2
    for item in $list; do
        case "$target" in
            "$item" | *."$item") return 0 ;;
        esac
    done
    return 1
}

# Function to check if target org matches list (case-insensitive)
match_org() {
    target=$1
    list=$2
    [ -z "$target" ] && return 1
    target_lower=$(echo "$target" | tr '[:upper:]' '[:lower:]')
    for item in $list; do
        item_lower=$(echo "$item" | tr '[:upper:]' '[:lower:]')
        if [ "$target_lower" = "$item_lower" ]; then
            return 0
        fi
    done
    return 1
}

# Function to resolve and normalize paths cross-platform
resolve_path() {
    path=$1
    # Replace ~ with $HOME
    path_resolved=$(echo "$path" | sed "s|^~|$HOME|")
    
    # If cygpath is available (Windows Git Bash), convert to Windows path
    if command -v cygpath >/dev/null 2>&1; then
        path_resolved=$(cygpath -w "$path_resolved" | tr '\\' '/')
    fi
    echo "$path_resolved"
}

# Determine identity
IDENTITY=""

# 1. Check remote URL if available
URL=$(git config remote.origin.url 2>/dev/null)
if [ -n "$URL" ]; then
    # Normalize URL: strip protocols, user, replace ':' with '/'
    CLEAN_URL=$URL
    CLEAN_URL=${CLEAN_URL#http://}
    CLEAN_URL=${CLEAN_URL#https://}
    CLEAN_URL=${CLEAN_URL#ssh://}
    CLEAN_URL=${CLEAN_URL#git://}
    CLEAN_URL=${CLEAN_URL#*@}
    CLEAN_URL=$(echo "$CLEAN_URL" | tr ':' '/')

    # Extract domain and org
    DOMAIN=${CLEAN_URL%%/*}
    PATH_AFTER_DOMAIN=${CLEAN_URL#*/}
    ORG=${PATH_AFTER_DOMAIN%%/*}
    ORG=${ORG%.git}

    # Match domain or org
    if echo "$DOMAIN" | grep -q -- "-work$"; then
        IDENTITY="work"
    elif echo "$DOMAIN" | grep -q -- "-personal$"; then
        IDENTITY="personal"
    elif match_org "$ORG" "$WORK_ORGS"; then
        IDENTITY="work"
    elif match_org "$ORG" "$PERSONAL_ORGS"; then
        IDENTITY="personal"
    elif match_domain "$DOMAIN" "$WORK_DOMAINS"; then
        IDENTITY="work"
    elif match_domain "$DOMAIN" "$PERSONAL_DOMAINS"; then
        IDENTITY="personal"
    fi
fi

# 2. Check path if identity still not determined
if [ -z "$IDENTITY" ]; then
    REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$REPO_PATH" ]; then
        # Normalize paths for comparison (convert \ to / and lowercase)
        REPO_PATH_NORM=$(echo "$REPO_PATH" | tr '\\' '/' | tr '[:upper:]' '[:lower:]')
        
        if [ -n "$WORK_DIR" ]; then
            WORK_DIR_NORM=$(echo "$WORK_DIR" | tr '\\' '/' | tr '[:upper:]' '[:lower:]')
            if echo "$REPO_PATH_NORM" | grep -q "^$WORK_DIR_NORM"; then
                IDENTITY="work"
            fi
        fi
        
        if [ -z "$IDENTITY" ] && [ -n "$PERSONAL_DIR" ]; then
            PERSONAL_DIR_NORM=$(echo "$PERSONAL_DIR" | tr '\\' '/' | tr '[:upper:]' '[:lower:]')
            if echo "$REPO_PATH_NORM" | grep -q "^$PERSONAL_DIR_NORM"; then
                IDENTITY="personal"
            fi
        fi
    fi
fi

# 3. Fallback to default
if [ -z "$IDENTITY" ]; then
    IDENTITY="$DEFAULT_IDENTITY"
fi

# Apply the identity configuration locally
if [ "$IDENTITY" = "work" ]; then
    if [ -n "$WORK_EMAIL" ]; then
        git config user.email "$WORK_EMAIL"
    fi
    WORK_KEY_RESOLVED=$(resolve_path "$WORK_KEY")
    git config core.sshCommand "ssh -i \"$WORK_KEY_RESOLVED\" -o IdentitiesOnly=yes"
    echo "[Duality] Configured local repository: Work ($WORK_EMAIL)" >&2
elif [ "$IDENTITY" = "personal" ]; then
    if [ -n "$PERSONAL_EMAIL" ]; then
        git config user.email "$PERSONAL_EMAIL"
    fi
    PERSONAL_KEY_RESOLVED=$(resolve_path "$PERSONAL_KEY")
    git config core.sshCommand "ssh -i \"$PERSONAL_KEY_RESOLVED\" -o IdentitiesOnly=yes"
    echo "[Duality] Configured local repository: Personal ($PERSONAL_EMAIL)" >&2
fi
