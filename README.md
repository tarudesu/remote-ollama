<div align="center">
  <h1>🚀 Remote Ollama Manager</h1>
  <p><i>Effortlessly orchestrate remote GPU-powered Ollama instances from your local machine.</i></p>
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
  [![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
  [![Ollama](https://img.shields.io/badge/AI-Ollama-white.svg)](https://ollama.com)
</div>

---

**Remote Ollama Manager** is a lightweight, zero-dependency bash utility designed to solve the headaches of running large language models on remote GPU servers.

Instead of wrestling with manual SSH port forwarding, systemd configurations, and GPU memory leaks caused by zombie `llama-server` processes, this tool provides a unified, highly secure command-line interface to orchestrate everything locally.

## ✨ Key Features

- 🛡️ **Interactive & Secure Configuration**: Setup connections to your remote GPU server effortlessly. Credentials are saved securely with restricted file permissions outside of version control.
- 🔑 **Zero-Password SSH**: Automatically generates and configures Ed25519 SSH keys and `~/.ssh/config` shortcuts for seamless, passwordless access.
- 🚇 **Automated Tunneling**: Establishes secure local port forwarding (`localhost:11434` → `remote:11434`). Your local applications (like LM Studio or AnythingLLM) will connect as if you had an H100 running under your desk.
- 🧹 **Clean Shutdowns**: Gracefully tears down tunnels and strictly terminates remote Ollama processes to eliminate GPU memory leaks when you're done.
- 📦 **Smart Model Management**: Automatically pulls your required models on startup if they are missing from the remote host.
- 🔒 **Hardened Execution**: Uses `jq` to serialize JSON safely and pipes payloads directly into SSH, completely mitigating shell injection vulnerabilities.

## 💡 Automatic Lifecycle Features

To ensure a zero-friction experience:
- **Automatic Installation**: When you run `remote-ollama init`, the script checks if `ollama` is installed on your remote GPU server. If it's missing, it automatically installs it for you.
- **Automatic Model Retrieval**: When you run `remote-ollama connect`, the script checks if your configured models (e.g., `qwen3.5:0.8b`) are already downloaded on the server. If any are missing, it automatically triggers a remote download (`ollama pull`) before launching.

## 🛠️ Prerequisites

- **Local Machine**: macOS or Linux (Requires: `bash`, `ssh`, `jq`, Python 3 for test parsing).
- **Remote Server**: Any Linux server with GPU access (Ubuntu, Debian, etc.).

## 🚀 Installation

### Option 1: Install via Homebrew (macOS & Linux)

You can install `remote-ollama` directly using Homebrew:

```bash
brew tap yourusername/remote-ollama
brew install remote-ollama
```

### Option 2: Manual Installation (Clone & Alias)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/remote-ollama.git
   cd remote-ollama
   chmod +x remote-ollama.sh
   ```

2. **Set up a global alias:**
   Add the following line to your `~/.zshrc` or `~/.bashrc`:
   ```bash
   alias remote-ollama="/path/to/your/remote-ollama/remote-ollama.sh"
   ```
   Then reload your shell environment:
   ```bash
   source ~/.zshrc
   ```

## 📖 Usage Guide

The tool uses a simple sub-command structure. 

### 1. ⚙️ Configuration Setup (`setup`)
Configure your server details. It interactively asks for Host Alias, Server IP Address, SSH Port, Username, SSH Key Path, Local Tunnel Port, and remote Ollama Port:
```bash
remote-ollama setup
```
*Note: This saves your configuration to `~/.remote-ollama.env` with strict `0600` permissions, keeping your IP and usernames safe.*

### 2. 🏗️ Initialization (`init`)
Sets up SSH keys, modifies your local `~/.ssh/config` file, copy the public key to the remote server, and installs Ollama on the remote host if not already present:
```bash
remote-ollama init
```

### 3. 🔌 Connect Service (`connect`)
Starts the remote Ollama service, establishes the local port-forwarding SSH tunnel (`localhost:11434` -> `remote:11434`), and pulls any missing models defined in your config:
```bash
remote-ollama connect
```
*Once connected, point your local clients to `http://localhost:11434`.*

### 4. 💬 Interactive Chat (`chat`)
Start a native, interactive chat session directly in your terminal. It lists all available models on the remote server, lets you select one, and launches the interactive Ollama chat session:
```bash
remote-ollama chat
```
*Note: If only one model is available, the script will select it automatically.*

### 5. 📊 Check Status (`status`)
Check the status of the local port-forwarding tunnel, remote Ollama service, installed models, and real-time GPU utilization (`nvidia-smi`):
```bash
remote-ollama status
```

### 6. 🧪 Test Connection (`test`)
Send a quick test query to ensure inference is working properly through the local tunnel:
```bash
remote-ollama test "Explain quantum computing in one sentence."
```

### 7. 📦 Pull Model (`pull`)
Download a new model onto the remote server:
```bash
remote-ollama pull qwen3.5:0.8b
```

### 8. 🔌 Disconnect Service (`disconnect`)
Tears down the local SSH tunnel and cleanly kills remote Ollama and runner processes to release GPU VRAM:
```bash
remote-ollama disconnect
```

### 9. 💥 Full Reset (`reset`)
A complete "back to zero" command. Revokes the SSH key from the remote server's `authorized_keys`, removes the host alias configuration from your `~/.ssh/config`, and deletes local SSH keys:
```bash
remote-ollama reset
```

---

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! 

## 📜 License
This project is licensed under the MIT License.

---
<div align="center">
  <i>Developed with ❤️ for the open-source community.</i>
</div>
