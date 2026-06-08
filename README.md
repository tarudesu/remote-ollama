# Remote Ollama Manager

`remote-ollama` is a lightweight bash utility to effortlessly manage, deploy, and connect to an Ollama instance running on a remote GPU server. 

Instead of dealing with manual SSH port forwarding, systemd configurations, and GPU memory leaks when Ollama processes zombie out, this tool provides a simple command-line interface to orchestrate everything from your local machine.

## Features

- **Interactive Configuration**: Setup connections to your remote GPU server easily.
- **Zero-Password SSH**: Automatically configures Ed25519 SSH keys and `~/.ssh/config` shortcuts for seamless access.
- **Automated Tunneling**: Sets up secure local port forwarding (`localhost:11434` -> `remote:11434`) so your local apps (like LM Studio or AnythingLLM) can connect to the remote GPU seamlessly.
- **Clean Shutdowns**: Gracefully kills remote Ollama processes and `llama-server` instances to free up GPU memory when you're done.
- **Model Management**: Automatically pulls your required models on startup if they are missing.

## Prerequisites

- Local Machine: macOS or Linux (bash, ssh, grep, awk).
- Remote Server: Any Linux server with GPU access (Ubuntu, Debian, etc.).
- Python 3 installed locally (optional, for the `test` command output parsing).

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/tarudesu/remote-ollama.git
   cd remote-ollama
   chmod +x remote-ollama.sh
   ```

2. **Set up a global alias (optional but recommended):**
   Add the following line to your `~/.zshrc` or `~/.bashrc`:
   ```bash
   alias remote-ollama="/path/to/your/remote-ollama/remote-ollama.sh"
   ```
   Then reload your shell: `source ~/.zshrc`

## Usage

### 1. Configuration (`config`)
Run the configuration setup. It will interactively ask for your server details:
```bash
remote-ollama config
```
*This saves your configuration to `~/.remote-ollama.env` safely outside the repository.*

### 2. Initialization (`init`)
Sets up SSH keys, modifies `~/.ssh/config`, copies the key to the server, and installs Ollama remotely if not present:
```bash
remote-ollama init
```

### 3. Start Service (`start`)
Starts the remote Ollama service, establishes the SSH port-forwarding tunnel, and pulls any missing models:
```bash
remote-ollama start
```
*Once running, your local apps can connect to `http://localhost:11434` as if Ollama is running locally!*

### 4. Check Status (`status`)
Check the status of the local tunnel, remote service, and GPU utilization:
```bash
remote-ollama status
```

### 5. Test Connection (`test`)
Send a quick query to test the inference through the tunnel:
```bash
remote-ollama test "Explain quantum computing in one sentence."
```

### 6. Stop Service (`stop`)
Tears down the local SSH tunnel and strictly kills remote Ollama processes to release GPU memory:
```bash
remote-ollama stop
```

### 7. Full Teardown (`shutdown`)
Stops all services, revokes the SSH key from the remote server, and deletes the local keys to revert to a completely clean state:
```bash
remote-ollama shutdown
```

## Contributing
Feel free to open an issue or submit a pull request if you have ideas for improvements.

## License
MIT
