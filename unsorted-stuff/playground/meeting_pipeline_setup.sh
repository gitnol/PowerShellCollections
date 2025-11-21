#!/bin/bash
# filepath: meeting_pipeline_setup.sh
# Production-ready setup script for Meeting Pipeline

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"
readonly VENV_PATH="${HOME}/meeting-pipeline-venv"
readonly REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
readonly CUDA_VERSION="12-4"  # System CUDA version
readonly PYTORCH_CUDA="cu121"  # PyTorch CUDA version
readonly PYTHON_VERSION="python3.10"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "INFO" "${GREEN}${*}${NC}"; }
log_warn() { log "WARN" "${YELLOW}${*}${NC}"; }
log_error() { log "ERROR" "${RED}${*}${NC}"; }

# Cleanup
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f "${SCRIPT_DIR}/cuda-keyring_1.1-1_all.deb"
    rm -f "${SCRIPT_DIR}/ollama_install.sh"
}

error_handler() {
    local line_number=$1
    log_error "Script failed at line ${line_number}"
    log_error "Check ${LOG_FILE} for details"
    exit 1
}

trap 'error_handler ${LINENO}' ERR
trap cleanup EXIT

# Helpers
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

safe_download() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if wget --timeout=30 --tries=3 -O "${output}" "${url}"; then
            log_info "Successfully downloaded: ${url}"
            return 0
        fi
        retry_count=$((retry_count + 1))
        log_warn "Download failed, attempt ${retry_count}/${max_retries}"
        sleep 2
    done

    log_error "Failed to download ${url} after ${max_retries} attempts"
    return 1
}

# Check system requirements
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Ubuntu version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]] || [[ "${VERSION_ID%%.*}" -lt 20 ]]; then
            log_error "This script requires Ubuntu 20.04 or newer"
            return 1
        fi
        log_info "Running on $PRETTY_NAME"
    fi
    
    # Check disk space (need at least 15GB)
    local available_space=$(df -BG "${HOME}" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 15 ]; then
        log_warn "Low disk space: ${available_space}GB available (15GB recommended)"
    fi
}

# Main
main() {
    log_info "==== Ubuntu Meeting-Pipeline Setup (Production) ===="
    log_info "Log file: ${LOG_FILE}"
    
    check_prerequisites

    # Step 1: System update
    log_info "Step 1: Updating system packages..."
    sudo apt update && sudo apt upgrade -y

    # Step 2: Basic tools
    log_info "Step 2: Installing basic tools..."
    local packages=(
        build-essential
        git
        wget
        curl
        ${PYTHON_VERSION}
        ${PYTHON_VERSION}-venv
        python3-pip
        ffmpeg
        sox
        libsox-fmt-all
        libportaudio2
        portaudio19-dev
        libsndfile1
    )
    
    for package in "${packages[@]}"; do
        if ! package_installed "${package}"; then
            log_info "Installing ${package}..."
            sudo apt install -y "${package}"
        else
            log_info "${package} already installed"
        fi
    done

    # Step 3: NVIDIA & CUDA
    if lspci | grep -iq nvidia; then
        log_info "Step 3: NVIDIA GPU detected, setting up drivers and CUDA..."
        
        if ! command_exists nvidia-smi; then
            log_info "Installing NVIDIA drivers..."
            sudo ubuntu-drivers autoinstall
        else
            log_info "NVIDIA driver already installed: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)"
        fi

        local cuda_path="/usr/local/cuda-${CUDA_VERSION//-/.}"
        if [ -d "${cuda_path}" ]; then
            log_info "CUDA Toolkit already installed at ${cuda_path}"
        else
            log_info "Installing CUDA Toolkit ${CUDA_VERSION}..."
            local cuda_keyring="${SCRIPT_DIR}/cuda-keyring_1.1-1_all.deb"
            safe_download "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb" "${cuda_keyring}"
            sudo dpkg -i "${cuda_keyring}"
            sudo apt update
            sudo apt install -y "cuda-toolkit-${CUDA_VERSION}" libcudnn8
        fi
        
        # Update PATH
        local bashrc="${HOME}/.bashrc"
        if ! grep -q "${cuda_path}/bin" "${bashrc}"; then
            log_info "Adding CUDA to PATH in .bashrc..."
            {
                echo ""
                echo "# CUDA Toolkit (added by meeting-pipeline-setup)"
                echo "export PATH=\"${cuda_path}/bin:\$PATH\""
                echo "export LD_LIBRARY_PATH=\"${cuda_path}/lib64\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}\""
            } >> "${bashrc}"
        fi
        
        export PATH="${cuda_path}/bin:$PATH"
        export LD_LIBRARY_PATH="${cuda_path}/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        
        log_info "NVIDIA setup complete: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)"
    else
        log_info "Step 3: No NVIDIA GPU detected, skipping CUDA setup"
    fi

    # Step 4: Python venv
    log_info "Step 4: Setting up Python virtual environment..."
    if [ ! -d "${VENV_PATH}" ]; then
        log_info "Creating virtual environment at ${VENV_PATH}..."
        ${PYTHON_VERSION} -m venv "${VENV_PATH}"
    fi
    
    # shellcheck disable=SC1091
    source "${VENV_PATH}/bin/activate"
    log_info "Virtual environment activated"

    # Step 5: Python packages
    log_info "Step 5: Installing Python packages..."
    pip install --upgrade pip wheel setuptools

    if [ ! -f "${REQUIREMENTS_FILE}" ]; then
        log_error "requirements.txt not found at ${REQUIREMENTS_FILE}"
        log_info "Creating minimal requirements.txt..."
        cat > "${REQUIREMENTS_FILE}" << EOF
# Core AI Libraries
--extra-index-url https://download.pytorch.org/whl/${PYTORCH_CUDA}
torch
torchvision
torchaudio

pyannote.audio==3.1.1
speechbrain
transformers
openai-whisper

# Helper & UI Libraries
streamlit
sounddevice
scipy
EOF
    fi
    
    log_info "Installing packages from ${REQUIREMENTS_FILE}..."
    pip install -r "${REQUIREMENTS_FILE}"

    # Verify PyTorch CUDA
    log_info "Verifying PyTorch installation..."
    if python -c "import torch; print(f'PyTorch {torch.__version__}')"; then
        if python -c "import torch; exit(0 if torch.cuda.is_available() else 1)" 2>/dev/null; then
            local gpu_name=$(python -c "import torch; print(torch.cuda.get_device_name(0))" 2>/dev/null)
            log_info "PyTorch CUDA support verified (Device: ${gpu_name})"
        else
            log_warn "PyTorch CUDA support NOT available, will run on CPU"
        fi
    else
        log_error "PyTorch installation failed"
        return 1
    fi

    # Step 6: whisper.cpp (optional)
    log_info "Step 6: Setting up whisper.cpp (optional)..."
    if [ ! -d "${HOME}/whisper.cpp" ]; then
        log_info "Cloning and building whisper.cpp..."
        git clone https://github.com/ggerganov/whisper.cpp.git "${HOME}/whisper.cpp"
        (cd "${HOME}/whisper.cpp" && make)
    else
        log_info "whisper.cpp already exists"
    fi

    # Step 7: Ollama
    log_info "Step 7: Installing Ollama..."
    if ! command_exists ollama; then
        log_info "Installing Ollama..."
        local ollama_installer="${SCRIPT_DIR}/ollama_install.sh"
        safe_download "https://ollama.com/install.sh" "${ollama_installer}"
        bash "${ollama_installer}"
    else
        if ollama --version &>/dev/null; then
            log_info "Ollama already installed: $(ollama --version 2>&1 | head -n1)"
        else
            log_info "Ollama already installed"
        fi
    fi

    # Step 8: Llama 3
    log_info "Step 8: Loading Llama 3 model..."
    if ! ollama list 2>/dev/null | grep -q "llama3"; then
        log_info "Downloading Llama 3 model (this may take several minutes)..."
        ollama pull llama3
    else
        log_info "Llama 3 model already available"
    fi

    log_info "==== Setup completed successfully! ===="
    echo ""
    log_info "Next steps:"
    echo "  1. Activate venv: source ${VENV_PATH}/bin/activate"
    echo "  2. IMPORTANT: Log in to Hugging Face to download AI models:"
    echo "     huggingface-cli login"
    echo "  3. If drivers were installed, a reboot is recommended: sudo reboot"
    echo "  4. Test CUDA: python -c 'import torch; print(torch.cuda.is_available())'"
    echo "  5. Start development!"
}

main "$@"