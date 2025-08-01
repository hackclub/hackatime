# HackaTime Doctor ⚕️ 

![Terminal Screenshot](terminal-screenshot.png)

A diagnostic tool that verifies your development environment meets all requirements for Hack Club's HackaTime and help in its setup and fixing.

## Features

### Core Checks
- ✅ Git installation check
- ✅ API connectivity test (HackaTime server)
- ✅ WakaTime config validation

### Optional Checks
- ✅ Project structure validation (README.md, LICENSE, .gitignore)
- ✅ Node.js installation & version check (v16+)

### Installation & Setup
- 🔄 Auto-install for missing packages 
- 🔍 Multi-package manager support:
  - Windows: Chocolatey (`choco`)
  - macOS: Homebrew (`brew`)
  - Linux:
    - APT (Debian/Ubuntu)
    - DNF/YUM (RHEL/Fedora)
    - Pacman (Arch)
    - Zypper (openSUSE)
    - APK (Alpine)
    - And many other package systems
- ⚙️ Interactive WakaTime config setup
- 🔐 Secure API key handling

### Reporting & Output
- 📊 JSON report generation
- 📈 CSV report generation
- 🎨 Color-coded terminal output
- 📋 Detailed error messages with remediation steps

### Cross-Platform Support
- 🖥️ Windows compatibility
- 🍏 macOS compatibility
- 🐧 Linux compatibility
- 🔄 Automatic path resolution (WAKATIME_HOME, XDG_CONFIG_HOME, etc.)

### Advanced Features
- 📂 Multi-location config file detection:
  - `~/.wakatime.cfg`
  - `~/.config/wakatime/.wakatime.cfg`
  - `/etc/wakatime.cfg`
- 🚦 Environment variable validation

### Quick Install (Recommended)

Download the latest release for your platform:

**[📥 Download Latest Release](https://github.com/arungeorgesaji/hackatime-doctor/releases/latest)**

#### Windows
1. Download the Windows release (`.zip` file)
2. Extract the zip file to your desired location
3. Open PowerShell in the extracted folder
4. Choco (Chocolatey) is required for the installation. If you don't have it installed, follow these steps:

   1. Open PowerShell as Administrator
   2. Run the following command to install Chocolatey:

      ```powershell
      iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
      ```

5. Install OpenSSL if not already installed (required for HTTPS requests), follow these steps:

    1. Open PowerShell as Administrator
    2. Run the following command to install OpenSSL:

       ```powershell
       choco install openssl
       ```
6. Set console encoding to UTF-8 (recommended for proper output display in powershell):

   ```powershell
   # Temporary (for current session only):
   [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

   # Permanent (add to PowerShell profile):
   Add-Content -Path $PROFILE -Value "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8"
   ```

6. Run the executable directly from the extracted folder, or for global access, copy hackatime-doctor.exe to a directory in your system PATH (like C:\Program Files\HackaTime Doctor) 
Note: You may need to run PowerShell as Administrator while running the script.

#### Linux/macOS
1. Download the appropriate release for your platform in your desired location
2. Extract the archive:

   ```bash
   tar -xzf hackatime-doctor-*.tar.gz
   ```
3. Run the installation script:

   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```

Note: Some minimal linux distros may not have which installedby default, most likely you wouldnt face an issue with this
command, but if you do, you can install it using your package manager.

### Build from Source

If you prefer to compile from source:

```bash
git clone https://github.com/arungeorgesaji/hackatime-doctor.git
cd hackatime-doctor
make
sudo make install
```

## Usage

After installation, run the diagnostic tool:

```bash
hackatime-doctor
```

Run extended diagnostics including project structure checks and checks for popular developer packages:

```bash
hackatime-doctor --full-check
```

> 🚧 **Beta Feature**  
> The `--full-check` currently includes basic extended validation.  

## Output Formats

Generate reports in multiple formats:

```bash
# Output to terminal 
hackatime-doctor

# JSON report
hackatime-doctor --json

# CSV report  
hackatime-doctor --csv
```
