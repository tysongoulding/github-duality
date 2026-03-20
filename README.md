GitHub Duality (Antigravity)
============================

**GitHub Duality** is a context-aware identity manager for developers who juggle multiple personalities (Work vs. Personal). It uses "Antigravity" logic to automatically swap your SSH keys and Git configurations based on which folder you are standing in.

No more manual git config user.email toggling. No more "Permission Denied" errors when pushing to a work repo with a personal key.

✨ Features
----------

*   **Context-Aware Identity**: Automatically switches between work and personal emails based on the directory path.
    
*   **SSH Key Routing**: Uses SSH Aliases to ensure the correct private key is presented to GitHub every time.
    
*   **Smart Cloning**: Includes helper functions (clone-work, clone-personal) to set up the "identity bridge" during the initial download.
    
*   **Cross-Platform**: Ready-to-use scripts for Windows (PowerShell) and Linux/macOS (Bash/Zsh).
    

🚀 Installation
---------------

### Windows (PowerShell)

Run this in an **Administrator** PowerShell terminal to ensure the SSH Agent service can be configured.

PowerShell

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser  .\setup-duality-windows.ps1   `

### Linux / macOS (Bash/Zsh)

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   chmod +x setup-duality-unix.sh  ./setup-duality-unix.sh   `

🛠 How it Works
---------------

The "Antigravity" logic relies on a three-tier handshake:

1.  **Directory Detection**: Your global .gitconfig uses includeIf to watch the C:/repo/work/ and C:/repo/personal/ folders.
    
2.  **Config Injection**: When you enter a folder, Git "injects" a sub-config containing your specific email and an SSH insteadOf rewrite.
    
3.  **SSH Aliasing**: The rewrite forces Git to talk to a custom SSH Host (e.g., github.com-work), which points directly to the correct IdentityFile in your ~/.ssh/config.
    

📖 The New Workflow
-------------------

Stop using the standard git clone for your initial setup. Use the built-in helpers to ensure the repository lands in the right "gravity well."

### For Work Projects

PowerShell

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   # Automatically clones to C:\repo\work\project-name using your work key  clone-work git@github.com:org/project-name.git   `

### For Personal Projects

PowerShell

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   # Automatically clones to C:\repo\personal\my-app using your personal key  clone-personal git@github.com:user/my-app.git   `

Once cloned, just use git normally. The system handles the rest.

⚠️ Important Note on SSH Keys
-----------------------------

After running the setup script, you **must** manually add your new public keys to your GitHub accounts:

1.  Copy the content of ~/.ssh/id\_ed25519.pub to your **Personal** GitHub settings.
    
2.  Copy the content of ~/.ssh/id\_ed25519\_work.pub to your **Work** GitHub settings.
    

### Troubleshooting

*   **Windows**: If your profile doesn't load the helpers, ensure your PowerShell profile path is correct ($PROFILE).
    
*   **SSH Agent**: If you get "Permission Denied," run ssh-add -l to ensure your keys are actually loaded into the agent.
