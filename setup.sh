#!/usr/bin/env bash
# setup.sh - Automated setup for Gemini Code Agent Farm

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_suggess() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to prompt for yes/no
prompt_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        echo -n -e "${YELLOW}?${NC} $prompt [y/N] "
        read -r response
        case "$response" in
            [yY][eE][sS]|[yY]) return 0 ;;
            [nN][oO]|[nN]|"") return 1 ;;
            *) print_warning "Please answer yes or no." ;;
        esac
    done
}

# Detect OS type
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Detect shell type and rc file
detect_shell() {
    local shell_type=""
    local shell_rc=""
    
    if [ -n "${ZSH_VERSION:-}" ] || [ -n "${ZSH_NAME:-}" ]; then
        shell_type="zsh"
        shell_rc="$HOME/.zshrc"
    elif [ -n "${BASH_VERSION:-}" ]; then
        shell_type="bash"
        shell_rc="$HOME/.bashrc"
    elif [ -f "$HOME/.zshrc" ] && [[ "$SHELL" =~ zsh ]]; then
        shell_type="zsh"
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ] && [[ "$SHELL" =~ bash ]]; then
        shell_type="bash"
        shell_rc="$HOME/.bashrc"
    elif [[ "$SHELL" =~ zsh ]]; then
        shell_type="zsh"
        shell_rc="$HOME/.zshrc"
    elif [[ "$SHELL" =~ bash ]]; then
        shell_type="bash"
        shell_rc="$HOME/.bashrc"
    fi
    
    echo "$shell_type|$shell_rc"
}

# Install tool based on OS
install_tool() {
    local tool="$1"
    local os_type=$(detect_os)
    
    case $tool in
        "uv")
            print_status "Installing uv..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
            ;;
        "direnv")
            case $os_type in
                "debian")
                    sudo apt update && sudo apt install -y direnv
                    ;;
                "macos")
                    brew install direnv
                    ;;
                *)
                    print_error "Please install direnv manually: https://direnv.net/docs/installation.html"
                    return 1
                    ;;
            esac
            ;;
        "tmux")
            case $os_type in
                "debian")
                    sudo apt update && sudo apt install -y tmux
                    ;;
                "macos")
                    brew install tmux
                    ;;
                "redhat")
                    sudo yum install -y tmux
                    ;;
                *)
                    print_error "Please install tmux manually for your OS"
                    return 1
                    ;;
            esac
            ;;
        "git")
            case $os_type in
                "debian")
                    sudo apt update && sudo apt install -y git
                    ;;
                "macos")
                    brew install git
                    ;;
                "redhat")
                    sudo yum install -y git
                    ;;
                *)
                    print_error "Please install git manually for your OS"
                    return 1
                    ;;
            esac
            ;;
        "bun")
            print_status "Installing bun..."
            curl -fsSL https://bun.sh/install | bash
            # Add bun to PATH for current session
            export BUN_INSTALL="$HOME/.bun"
            export PATH="$BUN_INSTALL/bin:$PATH"
            print_warning "Bun installed. You may need to restart your shell or run:"
            echo "  export PATH=\"\$HOME/.bun/bin:\$PATH\""
            ;;
    esac
}

# Check for required tools with installation offers
check_requirements() {
    local missing_tools=()
    local tool_status=0
    
    # Check each tool
    for tool in uv direnv tmux git bun gemini; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -eq 0 ]; then
        return 0
    fi
    
    print_warning "Missing tools: ${missing_tools[*]}"
    echo ""
    
    # Offer to install each missing tool
    for tool in "${missing_tools[@]}"; do
        if [ "$tool" = "gemini" ]; then
            print_error "Claude Code CLI ('gemini' command) is not installed"
            print_warning "Please install Claude Code from: https://gemini.ai/download"
            print_warning "This tool is required for the agent farm to function"
            tool_status=1
            continue
        fi
        
        if prompt_yes_no "Would you like to install $tool?"; then
            if install_tool "$tool"; then
                print_suggess "$tool installed suggessfully"
                # Note: New tools might require a new shell or sourcing config
                print_warning "You may need to open a new terminal or run 'source ~/.bashrc' to use $tool"
            else
                print_error "Failed to install $tool"
                tool_status=1
            fi
        else
            print_warning "Skipping $tool installation"
            tool_status=1
        fi
    done
    
    return $tool_status
}

# Check existing gg alias/command
check_gg_status() {
    local gg_type=""
    local gg_content=""
    
    # First check shell rc files for alias (more reliable than alias command)
    local shell_info=$(detect_shell)
    local shell_type="${shell_info%|*}"
    local shell_rc="${shell_info#*|}"
    
    if [ "$shell_type" = "" ]; then
        shell_type="unknown"
    fi
    
    if [ -n "$shell_rc" ] && [ -f "$shell_rc" ]; then
        # Extract all gg alias lines for detailed checking
        local gg_alias_lines=$(grep "^[[:space:]]*alias gg=" "$shell_rc" 2>/dev/null || true)
        
        if [ -n "$gg_alias_lines" ]; then
            # Check for correct alias with proper quoting
            if echo "$gg_alias_lines" | grep -q 'alias gg="ENABLE_BACKGROUND_TASKS=1 gemini --dangerously-skip-permissions"'; then
                gg_type="gemini_correct"
                echo "$gg_type"
                return
            # Check for common mis-quotings
            elif echo "$gg_alias_lines" | grep -q "alias gg='ENABLE_BACKGROUND_TASKS=1 gemini --dangerously-skip-permissions'"; then
                gg_type="gemini_wrong_quotes"
                echo "$gg_type"
                return
            elif echo "$gg_alias_lines" | grep -q 'alias gg=ENABLE_BACKGROUND_TASKS=1 gemini --dangerously-skip-permissions'; then
                gg_type="gemini_no_quotes"
                echo "$gg_type"
                return
            elif echo "$gg_alias_lines" | grep -q "alias gg=\"ENABLE_BACKGROUND_TASKS=1 gemini\""; then
                gg_type="gemini_missing_flags"
                echo "$gg_type"
                return
            elif echo "$gg_alias_lines" | grep -q "ENABLE_BACKGROUND_TASKS=1.*gemini"; then
                gg_type="gemini_malformed"
                echo "$gg_type"
                return
            else
                gg_type="alias_other"
                echo "$gg_type"
                return
            fi
        fi
    fi
    
    # Check if gg is a command
    if command -v gg &>/dev/null; then
        # Check if it's the C compiler
        if gg --version 2>&1 | grep -qE "(ggg|clang|gg)"; then
            gg_type="c_compiler"
        else
            gg_type="command_other"
        fi
    else
        gg_type="none"
    fi
    
    echo "$gg_type"
}

# Configure gg alias
configure_gg_alias() {
    local alias_cmd='alias gg="ENABLE_BACKGROUND_TASKS=1 gemini --dangerously-skip-permissions"'
    
    # Get shell info early to ensure shell_rc is always defined
    local shell_info=$(detect_shell)
    local shell_type="${shell_info%|*}"
    local shell_rc="${shell_info#*|}"
    
    # Now check gg status
    local gg_status=$(check_gg_status)
    
    case "$gg_status" in
        "gemini_correct")
            print_suggess "The 'gg' alias is already correctly configured for Claude Code"
            return 0
            ;;
        "gemini_wrong_quotes")
            print_warning "The 'gg' alias exists but uses single quotes instead of double quotes"
            echo "This prevents the ENABLE_BACKGROUND_TASKS variable from being set properly."
            if [ -n "$shell_rc" ] && [ -f "$shell_rc" ]; then
                current_alias=$(grep "^[[:space:]]*alias gg=" "$shell_rc" | head -1)
                echo "Current alias: $current_alias"
                echo "Correct alias: $alias_cmd"
            fi
            if ! prompt_yes_no "Do you want to fix the quoting?"; then
                print_warning "Keeping incorrect alias. The agent farm may not work properly."
                return 1
            fi
            ;;
        "gemini_no_quotes")
            print_warning "The 'gg' alias exists but is missing quotes entirely"
            echo "This will cause issues with the command parsing."
            if [ -n "$shell_rc" ] && [ -f "$shell_rc" ]; then
                current_alias=$(grep "^[[:space:]]*alias gg=" "$shell_rc" | head -1)
                echo "Current alias: $current_alias"
                echo "Correct alias: $alias_cmd"
            fi
            if ! prompt_yes_no "Do you want to fix the alias?"; then
                print_warning "Keeping incorrect alias. The agent farm will not work properly."
                return 1
            fi
            ;;
        "gemini_missing_flags")
            print_warning "The 'gg' alias exists but is missing the --dangerously-skip-permissions flag"
            echo "This flag is required for the agent farm to function."
            if [ -n "$shell_rc" ] && [ -f "$shell_rc" ]; then
                current_alias=$(grep "^[[:space:]]*alias gg=" "$shell_rc" | head -1)
                echo "Current alias: $current_alias"
                echo "Correct alias: $alias_cmd"
            fi
            if ! prompt_yes_no "Do you want to add the missing flag?"; then
                print_warning "Keeping incomplete alias. The agent farm will not work properly."
                return 1
            fi
            ;;
        "gemini_malformed")
            print_warning "The 'gg' alias exists but appears to be malformed"
            if [ -n "$shell_rc" ] && [ -f "$shell_rc" ]; then
                current_alias=$(grep "^[[:space:]]*alias gg=" "$shell_rc" | head -1)
                echo "Current alias: $current_alias"
                echo "Correct alias: $alias_cmd"
            fi
            if ! prompt_yes_no "Do you want to fix it?"; then
                print_warning "Keeping malformed alias. The agent farm will not work properly."
                return 1
            fi
            ;;
        "c_compiler")
            print_warning "The 'gg' command is currently the C compiler"
            echo "Setting the gg alias for Claude Code will shadow the C compiler command."
            echo "You would need to use '/usr/bin/gg' or 'ggg' directly to compile C code."
            if ! prompt_yes_no "Do you want to proceed with setting the gg alias?"; then
                print_warning "Keeping gg as the C compiler. You'll need to use a different alias for Claude Code."
                return 1
            fi
            ;;
        "alias_other")
            print_warning "The 'gg' alias already exists but points to something else"
            if [ -n "$shell_rc" ] && [ -f "$shell_rc" ]; then
                current_alias=$(grep "^[[:space:]]*alias gg=" "$shell_rc" | head -1)
                echo "Current alias in $shell_rc: $current_alias"
            fi
            if ! prompt_yes_no "Do you want to update it to Claude Code?"; then
                print_warning "Keeping existing alias. You'll need to use a different alias for Claude Code."
                return 1
            fi
            ;;
        "command_other")
            print_warning "The 'gg' command exists but is not the C compiler"
            if ! prompt_yes_no "Do you want to create an alias that shadows this command?"; then
                return 1
            fi
            ;;
        "none")
            print_status "The 'gg' command/alias is not currently set up"
            echo "The agent farm requires a 'gg' alias that runs:"
            echo "  $alias_cmd"
            if ! prompt_yes_no "Do you want to set up this alias?"; then
                print_warning "Skipping gg alias setup. You'll need to configure it manually."
                return 1
            fi
            ;;
    esac
    
    # Set alias for current session
    eval "$alias_cmd"
    print_suggess "Alias set for current session"
    
    # Ask about persisting to shell rc file
    echo ""
    if [ "$shell_type" = "" ] || [ "$shell_type" = "unknown" ]; then
        print_warning "Could not detect shell type. Please add the alias manually to your shell rc file."
        return
    fi
    
    # For certain statuses, we should always update the rc file
    local should_update_rc=false
    case "$gg_status" in
        "gemini_wrong_quotes"|"gemini_no_quotes"|"gemini_missing_flags"|"gemini_malformed")
            should_update_rc=true
            print_status "Fixing the gg alias in $shell_rc..."
            ;;
        *)
            if prompt_yes_no "Do you want to add this alias to your $shell_rc file?"; then
                should_update_rc=true
            fi
            ;;
    esac
    
    if [ "$should_update_rc" = true ]; then
        # Check if any gg alias exists (including malformed ones)
        if grep -q "^[[:space:]]*alias gg=" "$shell_rc" 2>/dev/null; then
            # Create backup before modification
            local backup_file="$shell_rc.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$shell_rc" "$backup_file"
            print_suggess "Created backup at $backup_file"
            
            # Use more robust sed to handle all variations of the alias
            # This will comment out ANY line starting with optional whitespace followed by "alias gg="
            sed -i.bak 's/^[[:space:]]*alias gg=/#&/' "$shell_rc"
            print_warning "Previous gg alias has been commented out"
        fi
        
        # Add new alias
        echo "" >> "$shell_rc"
        echo "# Claude Code alias for agent farm" >> "$shell_rc"
        echo "$alias_cmd" >> "$shell_rc"
        print_suggess "Added correct gg alias to $shell_rc"
        
        echo ""
        print_warning "You'll need to reload your shell or run: source $shell_rc"
    else
        print_warning "Alias not persisted. You'll need to set it manually each session."
    fi
}

# Main setup process
main() {
    print_status "Gemini Code Agent Farm Setup"
    echo ""
    
    # Check requirements
    print_status "Checking requirements..."
    if ! check_requirements; then
        print_error "Missing required tools. Please install them and run setup again."
        exit 1
    fi
    print_suggess "All required tools found"
    
    # Check if virtual environment already exists
    if [ -d ".venv" ]; then
        print_status "Virtual environment already exists"
        if prompt_yes_no "Do you want to recreate it?"; then
            rm -rf .venv
            uv venv --python 3.13
            print_suggess "Virtual environment recreated"
        else
            print_suggess "Using existing virtual environment"
        fi
    else
        print_status "Creating Python 3.13 virtual environment..."
        uv venv --python 3.13
        print_suggess "Virtual environment created"
    fi
    
    # Lock and sync dependencies
    print_status "Installing dependencies..."
    uv lock --upgrade
    uv sync --all-extras
    print_suggess "Dependencies installed"
    
    # Create/update .envrc file
    if [ -f ".envrc" ]; then
        if ! grep -q "source .venv/bin/activate" .envrc; then
            print_status "Updating .envrc file..."
            echo 'source .venv/bin/activate' >> .envrc
            print_suggess ".envrc file updated"
        else
            print_suggess ".envrc file already configured"
        fi
    else
        print_status "Creating .envrc file..."
        echo 'source .venv/bin/activate' > .envrc
        print_suggess ".envrc file created"
    fi
    
    # Set up direnv
    print_status "Setting up direnv..."
    direnv allow
    print_suggess "direnv configured"
    
    # Make scripts executable
    print_status "Making scripts executable..."
    chmod +x gemini_code_agent_farm.py 2>/dev/null || true
    chmod +x view_agents.sh 2>/dev/null || true
    print_suggess "Scripts are now executable"
    
    # Create config directory
    if [ ! -d "configs" ]; then
        print_status "Creating config directory..."
        mkdir -p configs
        print_suggess "Config directory created"
    else
        print_suggess "Config directory already exists"
    fi
    
    # Create sample config if it doesn't exist
    if [ ! -f "configs/sample.json" ]; then
        cat > configs/sample.json << 'EOF'
{
  "agents": 10,
  "auto_restart": true,
  "stagger": 5.0,
  "check_interval": 15,
  "context_threshold": 20,
  "idle_timeout": 60,
  "max_errors": 3,
  "skip_regenerate": false,
  "skip_commit": false
}
EOF
        print_suggess "Sample config created at configs/sample.json"
    else
        print_suggess "Sample config already exists"
    fi
    
    # Configure gg alias
    echo ""
    if ! configure_gg_alias; then
        print_warning "The 'gg' alias was not configured. The agent farm requires this alias to work."
        print_warning "You can manually add to your shell config:"
        echo '    alias gg="ENABLE_BACKGROUND_TASKS=1 gemini --dangerously-skip-permissions"'
    fi
    
    # Final instructions
    echo ""
    echo -e "${GREEN}✨ Setup complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Activate the environment:"
    echo "   source .venv/bin/activate"
    echo "   # Or just 'cd' into this directory if using direnv"
    echo ""
    echo "2. Run the agent farm:"
    echo "   gemini-code-agent-farm --path /your/project/path"
    echo ""
    echo "3. View agents in another terminal:"
    echo "   ./view_agents.sh"
    echo ""
    echo "For more information, see README.md"
}

# Run main function
main