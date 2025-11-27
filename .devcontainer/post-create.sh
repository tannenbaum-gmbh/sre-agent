#!/bin/bash
# Post-create script for Azure SRE Agent devcontainer

set -e

echo "🚀 Setting up Azure SRE Agent development environment..."

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
curl -fsSL https://aka.ms/install-azd.sh | bash

# Install Azure MCP Server package globally for agentic tooling
echo "📦 Installing Azure MCP Server for agentic tooling..."
npm install -g @azure/mcp

# Install additional useful npm packages for development
echo "📦 Installing development dependencies..."
npm install -g typescript ts-node

# Set up Azure CLI extensions for SRE and monitoring
echo "📦 Installing additional Azure CLI extensions..."
az extension add --name monitor-control-service --yes || true
az extension add --name log-analytics --yes || true
az extension add --name amg --yes || true

# Ensure MCP configuration directory exists
echo "🔧 Verifying MCP configuration..."
mkdir -p /workspaces/sre-agent/.vscode

# Check if MCP config exists, if not create a basic one
if [ ! -f /workspaces/sre-agent/.vscode/mcp.json ]; then
  cat > /workspaces/sre-agent/.vscode/mcp.json << 'EOF'
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
