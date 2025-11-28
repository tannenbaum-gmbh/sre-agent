# sre-agent

Repo to consolidate Azure SRE Agent demos and resources

## Sample Application

This repository includes a .NET 9 web application (`src/SreAgentDemo`) that demonstrates Azure App Service deployment slots, error simulation, and integration with the Azure SRE (Site Reliability Engineering) Agent for AI-assisted troubleshooting.

### How the Demo App Works

- **Normal Mode**: The main page shows a counter and two buttons: **Increment** and **Reset Counter**
- **Error Simulation**: When the `INJECT_ERROR` app setting is set to `1`, clicking "Increment" 6 times triggers an HTTP 500 error
- **Deployment Slots**: The "broken" slot has error injection enabled by default for testing failures without affecting production

### Running Locally

```bash
cd src/SreAgentDemo

# Run with error injection disabled
dotnet run

# Run with error injection enabled
INJECT_ERROR=1 dotnet run
```

The app will be available at `http://localhost:5121` or `https://localhost:7159`.

### Application Files

| File                                            | Description                         |
| ----------------------------------------------- | ----------------------------------- |
| `src/SreAgentDemo/Program.cs`                   | Main app logic and web server setup |
| `src/SreAgentDemo/appsettings.json`             | App configuration (default)         |
| `src/SreAgentDemo/appsettings.Development.json` | Development environment config      |
| `src/SreAgentDemo/SreAgentDemo.csproj`          | Project file                        |

## Infrastructure Deployment

This repository includes Bicep Infrastructure as Code (IaC) to deploy the complete SRE Agent demo environment, including:

- **Azure App Service** with deployment slots for failure simulation
- **Azure Chaos Studio** for chaos engineering experiments
- **Azure Load Testing** for simulating user traffic
- **Application Insights** for monitoring
- **Log Analytics Workspace** for diagnostics

### Quick Deployment

```bash
# Login to Azure
az login --tenant <yourtenant>

# Deploy the infrastructure (subscription-level deployment)
az deployment sub create \
  --name sre-agent-demo-resources \
  --location swedencentral \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json
```

### Customizing Deployment

Edit `infra/main.parameters.json` to customize:

| Parameter                   | Description              | Default             |
| --------------------------- | ------------------------ | ------------------- |
| `namePrefix`                | Prefix for all resources | `sreagent`          |
| `location`                  | Azure region             | `swedencentral`     |
| `resourceGroupName`         | Resource group name      | `rg-sre-agent-demo` |
| `appServiceSkuName`         | App Service Plan SKU     | `S1`                |
| `runtimeStack`              | Web app runtime          | `DOTNETCORE\|9.0`   |
| `enableChaosStudio`         | Deploy Chaos Studio      | `true`              |
| `enableLoadTesting`         | Deploy Load Testing      | `true`              |
| `enableApplicationInsights` | Enable App Insights      | `true`              |

### Azure Verified Modules (AVM)

This infrastructure uses [Azure Verified Modules](https://github.com/Azure/bicep-registry-modules/tree/main/avm/res) where available:

- `avm/res/web/serverfarm` - App Service Plan
- `avm/res/web/site` - Web App
- `avm/res/operational-insights/workspace` - Log Analytics

### SRE Agent Setup

> **Note**: Azure SRE Agent is currently in Preview and must be configured via the Azure Portal.

After deploying the infrastructure:

1. Navigate to the [Azure Portal](https://portal.azure.com)
2. Search for **"Azure SRE Agent"** in the search bar
3. Select **"+ Create"** to create a new agent
4. Configure the agent:
   - **Subscription**: Your Azure subscription
   - **Resource Group**: Create new (e.g., `rg-sre-agent`)
   - **Name**: `my-sre-agent`
   - **Region**: East US 2 (or available region)
5. Select **"Select resource groups"** and choose the resource group containing your App Service
6. Click **"Create"**

For detailed setup instructions, see [Tutorial: Troubleshoot an App Service app using Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/troubleshoot-azure-app-service)

### Testing the Demo

1. **Verify the app is running**:

   - Open the Web App URL (from deployment outputs)
   - Click the "Increment" button several times

2. **Simulate a failure**:

   - In the Azure Portal, navigate to your App Service
   - Go to **Deployment > Deployment slots**
   - Click **Swap** to swap the `broken` slot to production
   - The app now has error injection enabled

3. **Let SRE Agent diagnose**:

   - Open SRE Agent in the Azure Portal
   - Chat: "What's wrong with my-sre-app?"
   - The agent will analyze and propose remediation (slot swap rollback)

4. **Run Chaos Experiment** (optional):
   - Navigate to **Chaos Studio > Experiments**
   - Select the chaos experiment
   - Click **Start** to test App Service resilience

### Load Testing Setup

After deploying the infrastructure, set up Azure Load Testing to simulate user traffic:

```bash
# Configure the load test (creates test and uploads JMeter script)
./infra/scripts/setup-load-test.sh rg-sre-agent-demo lt-sreagent app-sreagent.azurewebsites.net
```

This creates a load test with:

- **50 virtual users** simulating concurrent traffic
- **30-minute duration** with 60-second ramp-up
- **Random requests** to `/?crash=1` (Increment) and `/?safe=1` (Reset)
- **0.5-5 second delays** between requests

To run the load test:

```bash
# Via Azure CLI
az load test-run create \
  --load-test-resource lt-sreagent \
  --resource-group rg-sre-agent-demo \
  --test-id sre-agent-load-test \
  --test-run-id "run-$(date +%Y%m%d-%H%M%S)"
```

Or use the Azure Portal:

1. Navigate to **Load Testing > lt-sreagent**
2. Select **sre-agent-load-test**
3. Click **Run**

---

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

| Tool                          | Description                                                   |
| ----------------------------- | ------------------------------------------------------------- |
| **Azure CLI**                 | Command-line interface for Azure with Bicep support           |
| **Azure Developer CLI (azd)** | Developer-focused Azure tooling for templates and deployments |
| **Bicep**                     | Domain-specific language for deploying Azure resources        |
| **Azure MCP Server**          | Model Context Protocol server for agentic Azure workflows     |
| **Node.js**                   | JavaScript runtime for development                            |
| **Python 3.12**               | Python interpreter for scripting and automation               |
| **Docker-in-Docker**          | Container runtime for local development                       |
| **GitHub CLI**                | GitHub command-line interface                                 |

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
