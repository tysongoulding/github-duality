GitHub Duality
==============

**GitHub Duality** is a context-aware identity manager for developers who juggle multiple personalities (Work vs. Personal). It automatically swaps your SSH keys and Git configurations based on the folder you are in or the remote URL of the repository you are working on.

It works seamlessly across all command lines, IDEs (Cursor, Windsurf, VS Code), and agentic harnesses (Claude Code, Antigravity, etc.), even when repositories are cloned into temporary scratch directories outside your standard development folders.

✨ Features
----------

*   **Context-Aware Identity**: Automatically switches between work and personal email/SSH configurations based on the directory path and git remote URL.
*   **Global Hook Templates**: Automatically injects lightweight hook scripts (`post-checkout`, `pre-commit`, `pre-push`) into every cloned or initialized repository.
*   **SSH Identity Routing**: Uses Git's `core.sshCommand` to directly route authentication using the correct key, avoiding global SSH host alias collisions.
*   **Universal Tool Support**: Works out of the box with CLI commands, IDE git integrations, and agentic code runners that execute git in sandboxed scratchpads.
*   **Smart Manual Helper**: Provides a `git-duality` command to automatically detect and apply configuration to existing repositories, or force a specific identity.

🚀 Installation
---------------

### Windows (PowerShell)

Run this in an **Administrator** PowerShell terminal to ensure the SSH Agent service can be configured.

PowerShell
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\setup-duality-windows.ps1
```

### Linux / macOS (Bash/Zsh)

Bash
```
chmod +x setup-duality-unix.sh
./setup-duality-unix.sh
```

🛠 How it Works
---------------

The Duality logic relies on a multi-tier handshake:

1.  **Directory Detection (`includeIf`)**: Your global `.gitconfig` watches your main personal and work folders (e.g. `C:/repo/personal` and `C:/repo/work`).
2.  **Global Templates**: Git is configured to use a custom template directory (`~/.git-duality/templates`). Every time a repository is cloned or initialized, a small hook stub is added to `.git/hooks`.
3.  **Auto-Detection Hook**: When a git action (checkout, commit, push) occurs:
    - The hook calls the global `duality-hook.sh`.
    - It inspects the remote origin URL (checking matching domains or organization names configured during setup).
    - It falls back to checking the directory path.
    - It configures the local `.git/config` with `user.email` and `core.sshCommand "ssh -i <key_path> -o IdentitiesOnly=yes"`.
4.  **Local Isolation**: Because the key is specified directly in the repository's `core.sshCommand`, the configuration remains isolated to that repository and works inside any IDE, terminal, or agentic environment.

📖 The Workflow
--------------

### Automatic Setup
Simply clone your project or initialize it. If the remote URL matches a work organization (e.g. `git@github.com:my-work-org/my-project.git`), it will automatically configure itself for your work identity. Otherwise, it defaults to personal.

### For Existing Repositories / Manual Overrides
If you want to manually run auto-detection and install hooks on an existing repository:
```bash
git-duality
```

If you want to force-configure a repository to use a specific identity:
```bash
git-duality work
# or
git-duality personal
```

### Direct Clone Helpers (Optional)
You can still use the helper commands to clone directly into your default directories:

#### Work Projects
```bash
clone-work git@github.com:org/project-name.git
```

#### Personal Projects
```bash
clone-personal git@github.com:user/my-app.git
```

⚠️ Important Note on SSH Keys
-----------------------------

After running the setup script, you **must** manually add your new public keys to your GitHub accounts:

1.  Copy the content of `~/.ssh/id_ed25519.pub` to your **Personal** GitHub settings.
2.  Copy the content of `~/.ssh/id_ed25519_work.pub` to your **Work** GitHub settings.

### Troubleshooting

*   **Windows Profile**: If your profile doesn't load the helpers, verify that your profile loads successfully (`$PROFILE`).
*   **Manual Apply**: If an IDE/agent clones a repo and doesn't run the hooks immediately, run `git-duality` inside that repo's root directory.

