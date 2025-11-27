#!/bin/bash
# Post-create script for Azure SRE Agent devcontainer

set -e

echo "🚀 Setting up Azure SRE Agent development environment..."

# Get the workspace directory (default to current directory)
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"

# Update system packages
sudo apt-get update && sudo apt-get upgrade -y

# Verify Azure CLI installation
echo "✅ Verifying Azure CLI installation..."
az --version

# Verify Bicep installation
echo "✅ Verifying Bicep installation..."
az bicep version

# Install Azure Developer CLI (azd)
echo "📦 Installing Azure Developer CLI..."
AZD_INSTALLER="/tmp/install-azd.sh"
if curl -fsSL https://aka.ms/install-azd.sh -o "$AZD_INSTALLER"; then
  bash "$AZD_INSTALLER"
  rm -f "$AZD_INSTALLER"
else
  echo "⚠️  Failed to download Azure Developer CLI installer, skipping..."
fi

# Install Azure MCP Server package globally for agentic tooling
echo "📦 Installing Azure MCP Server for agentic tooling..."
npm install -g @azure/mcp

# Install additional useful npm packages for development
echo "📦 Installing development dependencies..."
npm install -g typescript ts-node

# Set up Azure CLI extensions for SRE and monitoring
echo "📦 Installing additional Azure CLI extensions..."
install_az_extension() {
  local ext_name="$1"
  if ! az extension show --name "$ext_name" &>/dev/null; then
    echo "  Installing $ext_name..."
    az extension add --name "$ext_name" --yes
  else
    echo "  $ext_name already installed"
  fi
}

install_az_extension "monitor-control-service"
install_az_extension "log-analytics"
install_az_extension "amg"

# Ensure MCP configuration directory exists
echo "🔧 Verifying MCP configuration..."
mkdir -p "${WORKSPACE_DIR}/.vscode"

# Check if MCP config exists, if not create a basic one
if [ ! -f "${WORKSPACE_DIR}/.vscode/mcp.json" ]; then
  cat > "${WORKSPACE_DIR}/.vscode/mcp.json" << 'EOF'
{
  "servers": {
    "Azure MCP Server": {
      "command": "npx",
      "args": ["-y", "@azure/mcp@latest", "server", "start"],
      "env": {}
    }
  }
}
EOF
  echo "✅ Created MCP configuration"
else
  echo "✅ MCP configuration already exists"
fi

echo "✅ Azure SRE Agent development environment setup complete!"
echo ""
echo "📋 Available tools:"
echo "  - Azure CLI (az) with Bicep support"
echo "  - Azure Developer CLI (azd)"
echo "  - Azure MCP Server for agentic tooling"
echo "  - Node.js with npm"
echo "  - Python 3.12"
echo "  - Docker-in-Docker"
echo "  - GitHub CLI"
echo ""
echo "🔐 Next steps:"
echo "  1. Run 'az login' to authenticate with Azure"
echo "  2. Run 'azd auth login' for Azure Developer CLI"
echo "  3. Use GitHub Copilot with MCP for agentic Azure workflows"
