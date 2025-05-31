#!/bin/bash

# Constants
HOST="0.0.0.0"
BASE_PORT=11432
OLLAMA_BINARY="/home/rmcdermo/ollama/bin/ollama"
LOG_DIR="ollama-server-logs"
SLEEP_INTERVAL=1

# Function to install Ollama
install_ollama() {
    echo "Ollama not found. Installing Ollama..."
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$OLLAMA_BINARY")"
    
    # Download and install Ollama
    curl -fsSL https://ollama.ai/install.sh | sh
    
    # Check if installation was successful
    if command -v ollama &> /dev/null; then
        echo "Ollama installed successfully."
        # Update OLLAMA_BINARY to use system installation
        OLLAMA_BINARY=$(which ollama)
    else
        echo "Error: Failed to install Ollama."
        exit 1
    fi
}

# Check if the number of GPUs is provided as an argument
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <num_gpus>"
    exit 1
fi

# Command-line argument
NUM_GPUS=$1

# Validate that NUM_GPUS is a positive integer
if ! [[ "$NUM_GPUS" =~ ^[0-9]+$ ]] || [[ "$NUM_GPUS" -le 0 ]]; then
    echo "Error: <num_gpus> must be a positive integer."
    exit 1
fi

# Check if Ollama is installed
if [[ ! -x "$OLLAMA_BINARY" ]] && ! command -v ollama &> /dev/null; then
    install_ollama
elif command -v ollama &> /dev/null && [[ ! -x "$OLLAMA_BINARY" ]]; then
    # Use system installation if available
    OLLAMA_BINARY=$(which ollama)
    echo "Using system Ollama installation at $OLLAMA_BINARY"
elif [[ ! -x "$OLLAMA_BINARY" ]]; then
    echo "Error: Ollama binary not found or not executable at $OLLAMA_BINARY"
    exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Start server instances
for ((i=0; i<NUM_GPUS; i++)); do
    PORT=$((BASE_PORT + i))
    LOG_FILE="${LOG_DIR}/${PORT}.log"

    # Environment variables
    export OLLAMA_LOAD_TIMEOUT="120m"
    export OLLAMA_KEEP_ALIVE="120m"
    export OLLAMA_NUM_PARALLEL="16"
    export OLLAMA_HOST="${HOST}:${PORT}"
    export CUDA_VISIBLE_DEVICES="$i"

    # Start server with nohup and log output
    nohup "$OLLAMA_BINARY" serve > "$LOG_FILE" 2>&1 &

    if [[ $? -eq 0 ]]; then
        echo "Started server instance $i on port ${PORT}, logging to ${LOG_FILE}"
    else
        echo "Error: Failed to start server instance $i on port ${PORT}"
    fi

    # Sleep interval between starting instances
    sleep "$SLEEP_INTERVAL"
done

echo "All server instances started successfully."

