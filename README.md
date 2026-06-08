<div align="center">
  <h1>🚀 Remote Ollama Manager</h1>
  <p><i>Effortlessly orchestrate remote GPU-powered Ollama instances from your local machine.</i></p>
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
  [![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
  [![Ollama](https://img.shields.io/badge/AI-Ollama-white.svg)](https://ollama.com)
</div>

---

**Remote Ollama Manager** is a lightweight, zero-dependency bash utility designed by **tarudesu** to solve the headaches of running large language models on remote GPU servers.

Instead of wrestling with manual SSH port forwarding, systemd configurations, and GPU memory leaks caused by zombie `llama-server` processes, this tool provides a unified, highly secure command-line interface to orchestrate everything locally.

## ✨ Key Features

- 🛡️ **Interactive & Secure Configuration**: Setup connections to your remote GPU server effortlessly. Credentials are saved securely with restricted file permissions outside of version control.
- 🔑 **Zero-Password SSH**: Automatically generates and configures Ed25519 SSH keys and `~/.ssh/config` shortcuts for seamless, passwordless access.
- 🚇 **Automated Tunneling**: Establishes secure local port forwarding (`localhost:11434` → `remote:11434`). Your local applications (like LM Studio or AnythingLLM) will connect as if you had an H100 running under your desk.
- 🧹 **Clean Shutdowns**: Gracefully tears down tunnels and strictly terminates remote Ollama processes to eliminate GPU memory leaks when you're done.
- 📦 **Smart Model Management**: Automatically pulls your required models on startup if they are missing from the remote host.
- 🔒 **Hardened Execution**: Uses `jq` to serialize JSON safely and pipes payloads directly into SSH, completely mitigating shell injection vulnerabilities.

## 🛠️ Prerequisites

- **Local Machine**: macOS or Linux (Requires: `bash`, `ssh`, `jq`, Python 3 for test parsing).
- **Remote Server**: Any Linux server with GPU access (Ubuntu, Debian, etc.).

## 🚀 Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/tarudesu/remote-ollama.git
   cd remote-ollama
   chmod +x remote-ollama.sh
   ```

2. **Set up a global alias (Highly Recommended):**
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

### 1. ⚙️ Configuration (`config`)
Run the configuration setup. It interactively asks for your server details:
```bash
remote-ollama config
```
*Note: This saves your configuration to `~/.remote-ollama.env` with strict `0600` permissions, keeping your IP and usernames safe.*

### 2. 🏗️ Initialization (`init`)
Sets up SSH keys, modifies your local `~/.ssh/config`, pushes the public key to the server, and installs Ollama remotely if not already present:
```bash
remote-ollama init
```

### 3. ▶️ Start Service (`start`)
Starts the remote Ollama service, establishes the SSH port-forwarding tunnel, and pulls any missing models:
```bash
remote-ollama start
```
*Once running, point your local clients to `http://localhost:11434`.*

### 4. 📊 Check Status (`status`)
Check the status of the local tunnel, remote service, installed models, and real-time GPU utilization (`nvidia-smi`):
```bash
remote-ollama status
```

### 5. 🧪 Test Connection (`test`)
Send a quick test query to ensure inference is working properly through the tunnel:
```bash
remote-ollama test "Explain quantum computing in one sentence."
```

### 6. 🛑 Stop Service (`stop`)
Tears down the local SSH tunnel and cleanly kills remote Ollama processes to release your GPU VRAM:
```bash
remote-ollama stop
```

### 7. 💥 Full Teardown (`shutdown`)
A complete "back to zero" command. Stops all services, revokes the SSH key from the remote server's `authorized_keys`, and deletes the local keys:
```bash
remote-ollama shutdown
```

---

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! 

## 📜 License
This project is licensed under the MIT License.

---
<div align="center">
  <i>Developed with ❤️ by <a href="https://github.com/tarudesu">tarudesu</a></i>
</div>
