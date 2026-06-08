#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
# (We don't set -e globally to handle specific command failures gracefully, but we'll use robust conditionals)

# Configuration Variables
CONFIG_FILE="${HOME}/.remote-ollama.env"

load_config() {
    if [ -f "${CONFIG_FILE}" ]; then
        source "${CONFIG_FILE}"
    fi
}

cmd_config() {
    echo -e "${BLUE}[INFO]${NC} Interactive Configuration Setup"
    
    read -p "SSH Host Alias [e.g., gpu-server]: " input_host
    REMOTE_HOST="${input_host:-gpu-server}"
    
    read -p "Server IP Address: " input_ip
    REMOTE_IP="${input_ip}"
    
    read -p "SSH Port [default 22]: " input_port
    REMOTE_PORT="${input_port:-22}"
    
    read -p "SSH Username [default root]: " input_user
    REMOTE_USER="${input_user:-root}"
    
    read -p "SSH Key Path [default ${HOME}/.ssh/${REMOTE_HOST}]: " input_key
    SSH_KEY_PATH="${input_key:-${HOME}/.ssh/${REMOTE_HOST}}"
    
    read -p "Local Tunnel Port [default 11434]: " input_local_port
    LOCAL_PORT="${input_local_port:-11434}"
    
    read -p "Remote Ollama Port [default 11434]: " input_remote_port
    REMOTE_PORT_OLLAMA="${input_remote_port:-11434}"
    
    read -p "Models to pull (comma separated) [default empty]: " input_models
    MODELS_STR="${input_models}"

    # Save to config file
    cat > "${CONFIG_FILE}" <<EOF
REMOTE_HOST="${REMOTE_HOST}"
REMOTE_IP="${REMOTE_IP}"
REMOTE_PORT="${REMOTE_PORT}"
REMOTE_USER="${REMOTE_USER}"
SSH_KEY_PATH="${SSH_KEY_PATH}"
LOCAL_PORT="${LOCAL_PORT}"
REMOTE_PORT_OLLAMA="${REMOTE_PORT_OLLAMA}"
MODELS_STR="${MODELS_STR}"
EOF
    chmod 600 "${CONFIG_FILE}"
    echo -e "${GREEN}[SUCCESS]${NC} Configuration saved to ${CONFIG_FILE}"
}

ensure_config() {
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo -e "${YELLOW}[WARNING]${NC} No configuration found. Let's set it up."
        cmd_config
    fi
    load_config
    
    # Parse models string into an array safely
    IFS=',' read -r -a MODELS <<< "${MODELS_STR}"
}

# Helper colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_ssh_connection() {
    log_info "Testing SSH connection to ${REMOTE_HOST}..."
    ssh -o ConnectTimeout=5 -o BatchMode=yes "${REMOTE_HOST}" "echo 'ok'" > /dev/null 2>&1
    return $?
}

cmd_init() {
    log_info "Starting environment initialization..."

    # 1. SSH Key Generation
    if [ ! -f "${SSH_KEY_PATH}" ]; then
        log_info "SSH key not found at ${SSH_KEY_PATH}. Generating one..."
        mkdir -p "$(dirname "${SSH_KEY_PATH}")"
        chmod 700 "$(dirname "${SSH_KEY_PATH}")"
        ssh-keygen -t ed25519 -f "${SSH_KEY_PATH}" -C "greennode" -N ""
        log_success "SSH key generated."
    else
        log_info "SSH key already exists at ${SSH_KEY_PATH}."
    fi

    # 2. Configure SSH Host Shortcut
    local ssh_config="${HOME}/.ssh/config"
    mkdir -p "$(dirname "${ssh_config}")"
    touch "${ssh_config}"
    chmod 600 "${ssh_config}"

    if ! grep -q "Host ${REMOTE_HOST}" "${ssh_config}"; then
        log_info "Adding Host configuration for '${REMOTE_HOST}' in ${ssh_config}..."
        cat >> "${ssh_config}" <<EOF

Host ${REMOTE_HOST}
    HostName ${REMOTE_IP}
    User ${REMOTE_USER}
    Port ${REMOTE_PORT}
    IdentityFile ${SSH_KEY_PATH}
    IdentitiesOnly yes
EOF
        log_success "SSH config added."
    else
        log_info "Host configuration for '${REMOTE_HOST}' already exists in ${ssh_config}."
    fi

    # 3. Copy SSH Key to Server
    if check_ssh_connection; then
        log_success "Passwordless SSH connection to '${REMOTE_HOST}' is already active!"
    else
        echo -n "Do you have a password for remote user '${REMOTE_USER}' to automate key copy? [y/N]: "
        read -r has_pwd
        has_pwd="${has_pwd:-n}"
        if [[ "$has_pwd" =~ ^[Yy]$ ]]; then
            log_info "Attempting to copy SSH key using password..."
            if cat "${SSH_KEY_PATH}.pub" | ssh -o ConnectTimeout=10 -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_IP}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"; then
                log_success "Successfully copied public key to remote server."
            else
                log_warning "Failed to copy key automatically. Falling back to manual method..."
                has_pwd="n"
            fi
        fi

        if [[ ! "$has_pwd" =~ ^[Yy]$ ]]; then
            local pub_key
            pub_key=$(cat "${SSH_KEY_PATH}.pub")
            echo -e "\n${YELLOW}========================================================================${NC}"
            echo -e "YOUR PUBLIC KEY:"
            echo -e "${GREEN}${pub_key}${NC}"
            echo -e "${YELLOW}========================================================================${NC}"
            echo -e "To register this key, copy and paste the following command on your server terminal"
            echo -e "(via your GreenNode Web Console terminal or your already-open IDE terminal):"
            echo -e ""
            echo -e "${BLUE}mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo \"${pub_key}\" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys${NC}"
            echo -e ""
            read -p "Once you have run the command on your server, press [ENTER] to verify..."
        fi
    fi

    # 4. Verify SSH Connection without Password
    if check_ssh_connection; then
        log_success "Passwordless SSH connection to '${REMOTE_HOST}' established successfully."
    else
        log_error "SSH key authentication verification failed. Please check your config."
        exit 1
    fi

    # 5. Install Ollama on Remote Server
    log_info "Checking if Ollama is installed on the remote server..."
    if ssh "${REMOTE_HOST}" "command -v ollama > /dev/null 2>&1"; then
        local remote_version
        remote_version=$(ssh "${REMOTE_HOST}" "ollama --version" 2>/dev/null)
        log_success "Ollama is already installed on the server: ${remote_version}"
    else
        log_info "Ollama not found on server. Installing Ollama on remote server..."
        if ssh "${REMOTE_HOST}" "curl -fsSL https://ollama.com/install.sh | sh"; then
            log_success "Ollama installed successfully on the server."
        else
            log_error "Ollama installation on server failed."
            exit 1
        fi
    fi

    log_success "Initialization process completed successfully!"
}

cmd_start() {
    log_info "Checking connection and starting Ollama..."

    # Check SSH Connection
    if ! check_ssh_connection; then
        log_error "Unable to connect to '${REMOTE_HOST}'. Make sure init was run and the server is online."
        exit 1
    fi

    # Start Ollama service on remote server
    log_info "Checking Ollama service status on remote server..."
    local is_running=false
    
    if ssh "${REMOTE_HOST}" "pgrep -x ollama > /dev/null 2>&1"; then
        is_running=true
        log_success "Ollama process is already running on the server."
    fi

    if [ "$is_running" = false ]; then
        log_info "Starting Ollama on remote server..."
        
        # Check if systemd is active and unit exists
        if ssh "${REMOTE_HOST}" "[ -d /run/systemd/system ] && systemctl list-unit-files | grep -q '^ollama.service' 2>/dev/null"; then
            log_info "Starting Ollama via systemd..."
            ssh "${REMOTE_HOST}" "systemctl start ollama"
        else
            log_info "systemd service not active or not found. Starting Ollama in the background via nohup..."
            ssh "${REMOTE_HOST}" "nohup ollama serve > ~/.ollama.log 2>&1 &"
        fi
    fi

    # Wait for Ollama to become responsive
    log_info "Waiting for remote Ollama API to become responsive..."
    local retries=30
    local success=false
    for ((i=1; i<=retries; i++)); do
        if ssh "${REMOTE_HOST}" "curl -s http://127.0.0.1:${REMOTE_PORT_OLLAMA}/api/tags" > /dev/null 2>&1; then
            success=true
            break
        fi
        sleep 1
    done

    if [ "$success" = false ]; then
        log_error "Ollama remote API failed to respond after ${retries} seconds."
        exit 1
    fi
    log_success "Remote Ollama API is responsive."

    # Pull configured models if missing
    for model in "${MODELS[@]}"; do
        # Trim whitespace
        model=$(echo "$model" | xargs)
        if [ -z "$model" ]; then continue; fi

        log_info "Checking model: ${model}..."
        if ssh "${REMOTE_HOST}" "ollama list" | grep -q "${model}"; then
            log_success "Model '${model}' is already available."
        else
            log_info "Model '${model}' is missing. Pulling now (this might take a few minutes)..."
            ssh "${REMOTE_HOST}" "ollama pull ${model}"
            log_success "Model '${model}' pulled successfully."
        fi
    done

    # Setup local tunnel
    log_info "Checking local port forwarding tunnel (Mac Port ${LOCAL_PORT} -> Server Port ${REMOTE_PORT_OLLAMA})..."
    local tunnel_pid
    tunnel_pid=$(pgrep -f "ssh.*-L ${LOCAL_PORT}:localhost:${REMOTE_PORT_OLLAMA} ${REMOTE_HOST}")
    
    if [ -n "$tunnel_pid" ]; then
        log_success "Local tunnel is already running with PID: ${tunnel_pid}."
    else
        log_info "Starting local port forwarding tunnel..."
        if ssh -f -N -L "${LOCAL_PORT}:localhost:${REMOTE_PORT_OLLAMA}" "${REMOTE_HOST}"; then
            log_success "Local tunnel established successfully."
            log_info "Local API endpoint: http://localhost:${LOCAL_PORT}"
        else
            log_error "Failed to establish local port forwarding tunnel."
        fi
    fi

    log_success "Ollama and tunnel are ready for use!"
}

cmd_stop() {
    log_info "Stopping Ollama and local tunnel..."

    # 1. Stop local tunnel
    log_info "Terminating local SSH tunnel..."
    local tunnel_pid
    tunnel_pid=$(pgrep -f "ssh.*-L ${LOCAL_PORT}:localhost:${REMOTE_PORT_OLLAMA} ${REMOTE_HOST}")
    
    if [ -n "$tunnel_pid" ]; then
        kill "$tunnel_pid"
        log_success "Local tunnel process (PID: ${tunnel_pid}) terminated."
    else
        log_info "No local SSH tunnel process found."
    fi

    # 2. Stop remote Ollama
    if check_ssh_connection; then
        log_info "Stopping remote Ollama service..."
        if ssh "${REMOTE_HOST}" "[ -d /run/systemd/system ] && systemctl list-unit-files | grep -q '^ollama.service' 2>/dev/null"; then
            log_info "Stopping via systemd..."
            ssh "${REMOTE_HOST}" "systemctl stop ollama"
        fi
        
        log_info "Ensuring all remote Ollama and runner processes are terminated..."
        ssh "${REMOTE_HOST}" "pkill -f 'ollama serve' || pkill -f 'llama-server' || pkill -f 'ollama'"
        log_success "Remote Ollama stopped."
    else
        log_warning "Could not connect to remote host '${REMOTE_HOST}' to stop Ollama. Server may be unreachable."
    fi

    log_success "Shutdown workflow complete."
}

cmd_status() {
    log_info "Gathering status info..."

    # Check local tunnel
    local tunnel_pid
    tunnel_pid=$(pgrep -f "ssh.*-L ${LOCAL_PORT}:localhost:${REMOTE_PORT_OLLAMA} ${REMOTE_HOST}")
    
    if [ -n "$tunnel_pid" ]; then
        log_success "Local SSH Tunnel: RUNNING (PID: ${tunnel_pid})"
        log_info "Local URL: http://localhost:${LOCAL_PORT}"
        # Test local API connection
        if curl -s "http://localhost:${LOCAL_PORT}/api/tags" > /dev/null; then
            log_success "Local Connection Check: SUCCESS"
        else
            log_warning "Local Connection Check: FAILED (Port open, but API not responding)"
        fi
    else
        log_warning "Local SSH Tunnel: NOT RUNNING"
    fi

    # Check remote connection
    if check_ssh_connection; then
        log_success "SSH Connection: OK"
        
        # Check remote Ollama process
        if ssh "${REMOTE_HOST}" "pgrep -x ollama > /dev/null 2>&1"; then
            log_success "Remote Ollama: RUNNING"
            # Remote tags / models
            log_info "Remote Models Installed:"
            ssh "${REMOTE_HOST}" "ollama list"
        else
            log_warning "Remote Ollama: NOT RUNNING"
        fi
        
        # Check systemd service if systemd is active and service is available
        if ssh "${REMOTE_HOST}" "[ -d /run/systemd/system ] && systemctl list-unit-files | grep -q '^ollama.service' 2>/dev/null"; then
            local svc_status
            svc_status=$(ssh "${REMOTE_HOST}" "systemctl is-active ollama" 2>/dev/null)
            log_info "Remote Systemd Service State: ${svc_status}"
        fi

        # Check GPU status
        log_info "Remote GPU Status (nvidia-smi):"
        if ssh "${REMOTE_HOST}" "command -v nvidia-smi >/dev/null 2>&1"; then
            ssh "${REMOTE_HOST}" "nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,utilization.memory --format=csv,noheader"
        else
            log_warning "nvidia-smi command not available on remote server."
        fi
    else
        log_error "SSH Connection: FAILED to connect to '${REMOTE_HOST}'"
    fi
}

cmd_test() {
    local prompt="$*"
    if [ -z "$prompt" ]; then
        prompt="Why is the sky blue?"
    fi
    
    # Use first model in MODELS array, default to llama3.2 if empty
    local model="llama3.2"
    if [ ${#MODELS[@]} -gt 0 ] && [ -n "${MODELS[0]}" ]; then
        model=$(echo "${MODELS[0]}" | xargs)
    fi
    
    log_info "Testing Ollama with model '${model}'..."
    log_info "Prompt: \"${prompt}\""

    # 1. Determine which endpoint to use
    local url="http://localhost:${LOCAL_PORT}"
    
    log_info "Checking if local SSH tunnel is active..."
    if ! curl -s -o /dev/null -w "%{http_code}" "${url}/api/tags" >/dev/null 2>&1; then
        log_warning "Local tunnel not responding. Checking if we can test directly on the remote server via SSH..."
        if check_ssh_connection; then
            log_info "Testing via remote SSH execution..."
            local escaped_prompt
            escaped_prompt=$(echo "${prompt}" | sed 's/"/\\"/g')
            local remote_json
            remote_json=$(ssh "${REMOTE_HOST}" "curl -s -X POST http://127.0.0.1:${REMOTE_PORT_OLLAMA}/api/generate -d '{\"model\": \"${model}\", \"prompt\": \"${escaped_prompt}\", \"stream\": false}'")
            if [ -n "$remote_json" ]; then
                log_success "Response from remote server:"
                echo "$remote_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('response', ''))" 2>/dev/null || echo "$remote_json"
            else
                log_error "Failed to get response from remote Ollama API."
            fi
        else
            log_error "Cannot connect to server or local tunnel. Please run 'auto-ollama start' first."
        fi
        return
    fi

    # 2. Local tunnel is active, test through it
    log_info "Sending query via local tunnel..."
    local escaped_prompt
    escaped_prompt=$(echo "${prompt}" | sed 's/"/\\"/g')
    local local_json
    local_json=$(curl -s -X POST "${url}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"${model}\", \"prompt\": \"${escaped_prompt}\", \"stream\": false}")

    if [ -n "$local_json" ]; then
        log_success "Response received:"
        echo "$local_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('response', ''))" 2>/dev/null || echo "$local_json"
    else
        log_error "Failed to get response from local tunnel."
    fi
}

cmd_shutdown() {
    log_info "Starting full shutdown and revocation..."

    # 1. Stop local tunnel and remote Ollama
    cmd_stop

    # 2. Revoke SSH key from remote server
    if [ -f "${SSH_KEY_PATH}.pub" ] && check_ssh_connection; then
        log_info "Revoking SSH key on the remote server..."
        local pub_key_content
        pub_key_content=$(cat "${SSH_KEY_PATH}.pub")
        # Use grep to remove the line containing the public key
        if ssh "${REMOTE_HOST}" "grep -vF '${pub_key_content}' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"; then
            log_success "SSH key successfully revoked from remote server's authorized_keys."
        else
            log_warning "Failed to revoke SSH key from remote server."
        fi
    else
        log_info "SSH key public file not found or remote host unreachable. Skipping remote revocation."
    fi

    # 3. Remove SSH configuration block from Mac ~/.ssh/config
    local ssh_config="${HOME}/.ssh/config"
    if [ -f "${ssh_config}" ]; then
        log_info "Removing SSH Host configuration from Mac config..."
        # macOS compatible sed to delete the block from Host greennode down to IdentitiesOnly yes
        if sed -i '' '/Host '"${REMOTE_HOST}"'/,/IdentitiesOnly yes/d' "${ssh_config}"; then
            log_success "SSH configuration block removed from ${ssh_config}."
        else
            log_warning "Failed to remove SSH config block from ${ssh_config}."
        fi
    fi

    # 4. Delete local SSH key files
    if [ -f "${SSH_KEY_PATH}" ] || [ -f "${SSH_KEY_PATH}.pub" ]; then
        log_info "Deleting local SSH key files..."
        rm -f "${SSH_KEY_PATH}" "${SSH_KEY_PATH}.pub"
        log_success "Local SSH key files deleted."
    fi

    log_success "Full shutdown and cleanup complete! You are now back to zero state."
}

# Print usage if no argument is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 {config|init|start|stop|status|shutdown|test}"
    exit 1
fi

case "$1" in
    config)
        cmd_config
        ;;
    init)
        ensure_config
        cmd_init
        ;;
    start)
        ensure_config
        cmd_start
        ;;
    stop)
        ensure_config
        cmd_stop
        ;;
    status)
        ensure_config
        cmd_status
        ;;
    shutdown)
        ensure_config
        cmd_shutdown
        ;;
    test)
        shift
        ensure_config
        cmd_test "$@"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Usage: $0 {config|init|start|stop|status|shutdown|test}"
        exit 1
        ;;
esac
