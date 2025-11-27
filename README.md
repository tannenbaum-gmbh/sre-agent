# sre-agent

Repo to consolidate Azure SRE Agent demos and resources

## Development Environment

This repository includes a fully configured devcontainer for Azure development with SRE Agent tooling.

### Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- An Azure subscription

### Getting Started

1. Clone this repository
2. Open the repository in VS Code
3. When prompted, click "Reopen in Container" or run the command `Dev Containers: Reopen in Container`
4. Wait for the container to build and initialize
5. Authenticate with Azure:
   ```bash
   az login
   azd auth login
   ```

### Included Tools

| Tool | Description |
|------|-------------|
| **Azure CLI** | Command-line interface for Azure with Bicep support |
| **Azure Developer CLI (azd)** | Developer-focused Azure tooling for templates and deployments |
| **Bicep** | Domain-specific language for deploying Azure resources |
| **Azure MCP Server** | Model Context Protocol server for agentic Azure workflows |
| **Node.js** | JavaScript runtime for development |
| **Python 3.12** | Python interpreter for scripting and automation |
| **Docker-in-Docker** | Container runtime for local development |
| **GitHub CLI** | GitHub command-line interface |

### Azure CLI Extensions

The following Azure CLI extensions are pre-installed:

- `azure-devops` - Azure DevOps integration
- `containerapp` - Azure Container Apps management
- `webapp` - Azure App Service management
- `monitor` - Azure Monitor management
- `application-insights` - Application Insights management
- `resource-graph` - Azure Resource Graph queries
- `monitor-control-service` - Monitor control service
- `log-analytics` - Log Analytics management
- `amg` - Azure Managed Grafana

### VS Code Extensions

The devcontainer includes recommended extensions for:

- **Azure Development**: Bicep, Azure Tools, App Service, Functions, Resource Groups
- **Agentic Tooling**: Azure MCP Server, GitHub Copilot, Copilot Chat
- **Infrastructure as Code**: Terraform, Azure Dev CLI
- **Languages**: Python, TypeScript, YAML, JSON
- **Productivity**: GitLens, ESLint, Prettier, EditorConfig

### MCP (Model Context Protocol) Configuration

The repository includes pre-configured MCP servers in `.vscode/mcp.json`:

- **Azure MCP Server**: Interact with Azure resources using natural language through GitHub Copilot
- **GitHub MCP Server**: Managed GitHub MCP endpoint for repository and workflow interactions
- **Microsoft Learn MCP Server**: Access official Microsoft documentation and code samples

To use MCP with GitHub Copilot:
1. Open Copilot Chat in VS Code
2. Switch to Agent Mode
3. The MCP servers will automatically connect

### Target Services

This development environment is optimized for working with:

- **Azure App Service** - Web application hosting
- **Azure Chaos Studio** - Chaos engineering experiments
- **Azure SRE Agent** - Site Reliability Engineering automation
- **Azure Monitor** - Observability and monitoring
- **Application Insights** - Application performance monitoring

## License

See [LICENSE](LICENSE) for details.
