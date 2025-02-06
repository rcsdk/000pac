#!/bin/bash

# Function to check if a package is installed
is_installed() {
    local package=$1
    pacman -Q "$package" &> /dev/null
}

# Function to check and install a package
install_package() {
    local package=$1
    if ! is_installed "$package"; then
        echo "Installing $package..."
        sudo pacman -S --noconfirm "$package"
        if [ $? -ne 0 ]; then
            echo "Failed to install $package. Exiting."
            exit 1
        fi
    else
        echo "$package is already installed."
    fi
}

# Function to add custom action in PCManFM
add_custom_action() {
    local name=$1
    local command=$2
    local file_pattern=$3
    local selection_type=$4
    echo "Adding custom action: $name"
    # Using gsettings to add custom actions
    gsettings set org.xfce.file-manager.preferences.custom-actions "$name" "[ \"$command\" \"$file_pattern\" \"$selection_type\" ]"
}

# Check for system compatibility
if ! mount | grep -q ' / '; then
    echo "This script requires a writable filesystem. Exiting."
    exit 1
fi

# Install PCManFM
install_package pcmanfm

# Install terminal emulators
install_package kitty
install_package alacritty
# Allacritty is the same as Alacritagritty, so we only need to install Alacritty once
# install_package allacritty

# Install dependencies
install_package curl
install_package jq

# Install text editor (fallback order: nvim, nano, vim)
if ! is_installed nvim; then
    install_package nvim
    EDITOR="nvim"
else
    EDITOR="nvim"
fi

if ! is_installed "$EDITOR"; then
    install_package nano
    EDITOR="nano"
fi

if ! is_installed "$EDITOR"; then
    install_package vim
    EDITOR="vim"
fi

if ! is_installed "$EDITOR"; then
    echo "Failed to install a text editor. Exiting."
    exit 1
fi

# Create AI script
AI_SCRIPT="/usr/local/bin/ai_script.sh"
echo "Creating AI script at $AI_SCRIPT..."
cat << 'EOF' > "$AI_SCRIPT"
#!/bin/bash

# API endpoint for OpenAI GPT-3
API_ENDPOINT="https://api.openai.com/v1/engines/davinci-codex/completions"
API_KEY="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"

# Function to get AI response
get_ai_response() {
    local prompt="$1"
    curl -s -X POST "$API_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d '{
      "prompt": "'"$prompt"'",
      "max_tokens": 150
    }' | jq -r '.choices[0].text'
}

# Read user input
read -p "Enter your query: " query

# Get AI response
response=$(get_ai_response "$query")

# Display response
echo "Response: $response"
EOF

chmod +x "$AI_SCRIPT"

# Configure Custom Actions in PCManFM
echo "Configuring custom actions in PCManFM..."

# Add custom actions for each terminal emulator
if is_installed kitty; then
    add_custom_action "Run Script in Kitty" "kitty bash -c \"/usr/local/bin/ai_script.sh; exec bash\"" "*.sh" "File"
    add_custom_action "Edit Script in Kitty" "kitty $EDITOR %f" "*.sh" "File"
fi

if is_installed alacritty; then
    add_custom_action "Run Script in Alacritty" "alacritty -e bash -c \"/usr/local/bin/ai_script.sh; exec bash\"" "*.sh" "File"
    add_custom_action "Edit Script in Alacritty" "alacritty -e $EDITOR %f" "*.sh" "File"
fi

# Attempt to install Warp (fallback if installation fails)
if ! is_installed warp; then
    echo "Attempting to install Warp..."
    if command -v curl &> /dev/null; then
        # Add Warp repository
        curl -sSf https://pkg.warp.dev/pacman/gpg.key | sudo pacman-key --add -
        sudo pacman-key --lsign-key 0xF182118E18E8D77E0A7336
        echo "[warp]" | sudo tee /etc/pacman.conf
        echo "Server = https://pkg.warp.dev/pacman/\$arch" | sudo tee -a /etc/pacman.conf
        sudo pacman -Syu --noconfirm warp
        if [ $? -ne 0 ]; then
            echo "Failed to install Warp. Skipping Warp custom actions."
        else
            add_custom_action "Run Script in Warp" "warp bash -c \"/usr/local/bin/ai_script.sh; exec bash\"" "*.sh" "File"
            add_custom_action "Edit Script in Warp" "warp $EDITOR %f" "*.sh" "File"
        fi
    else
        echo "Failed to install Warp: curl is not installed."
    fi
fi

echo "Setup complete. You can now right-click on .sh files to run or edit them using the configured terminal emulators."
