# Azure Infrastructure Repository

This repository provides PowerShell scripts and Bicep templates to deploy Azure resources and configure their dependencies.

Examples include:

* Creating a Key Vault and a Function App, and assigning the required permissions so the Function App can read secrets from the Key Vault.
* Creating Entra applications with permissions and an automatically generated secret, which is then stored securely in the Key Vault.
* Deploying an API to Azure API Management (APIM) and dynamically configuring the subscription key and policy.

While the resources are tailored for a specific application (not included here), the primary purpose of this repository is to demonstrate deployment practices.

## Prerequisites

* Install the latest version of PowerShell.
* Install Visual Studio Code along with the PowerShell extension.

## Running the scripts

* Open Visual Studio as an administrator (some modules require Administrator rights)
* Create an Entra app registration to be used by all scripts for authenticating to Azure. Detailed instructions are available in `DevOps\PowerShell\Deploy\Resources.ps1`
* (Optional) Create a Service Connection in Azure DevOps to enable pipelines to deploy resources to Azure. Note: This repository does not yet include a pipeline example; therefore, this value can be left empty.
* Provide all required parameters in `Resources.ps1`, as indicated in the section "Modify the parameters listed below."
* Run file `Resources.ps1`
* Review the PowerShell extension terminal to monitor deployment status and identify any errors.

## Notes

* Required PowerShell modules will be installed and imported automatically; allow extra time for this step.
* The deployment usually takes about 60 minutes.
* These scripts are designed to run on Windows environments.
* Certain scripts are provided only for testing and validation.

## Deployed resources
If the script runs without errors, the following resources will be deployed:


| NAME                                | TYPE                      | LOCATION        |
|-------------------------------------|---------------------------|-----------------|
| devfnconsumptionsto                 | Storage account           | West US 3       |
| devmainstoprv                       | Storage account           | West US 3       |
| devmainstopub                       | Storage account           | West US 3       |
| wwtp-dev-ain-01                     | Application Insights      | West US 3       |
| wwtp-dev-apim-01                    | API Management service    | West US 3       |
| wwtp-dev-cosmos-server-01           | Azure Cosmos DB account   | West US 3       |
| wwtp-dev-kv-01                      | Key vault                 | West US 3       |
| wwtp-dev-map-01                     | Azure Maps Account        | West Central US |
| wwtp-dev-prv-fn-01                  | Function App              | West US 3       |
| wwtp-dev-prv-fn-01/staging          | Function App              | West US 3       |
| wwtp-dev-pub-fn-01                  | Function App              | West US 3       |
| wwtp-dev-pub-fn-01/staging          | Function App              | West US 3       |
| wwtp-dev-redis-01                   | Azure Cache for Redis     | West US 3       |
| wwtp-dev-sql-server                 | SQL server                | West US 3       |
| wwtp-dev-web-app-01                 | App Service               | West US 3       |
| wwtp-dev-web-app-01/staging         | App Service (Slot)        | West US 3       |
| wwtp-dev-web-splan-01               | App Service plan          | West US 3       |
| wwtp-routing                        | SQL database              | West US 3       |
| wwtp-s1                             | SQL database              | West US 3       |
| wwtp-s61                            | SQL database              | West US 3       |
| wwtp-shard-map-manager              | SQL database              | West US 3       |


## Clean up

* To prevent incurring unnecessary costs, it is recommended to delete the entire resource group, which will remove all associated resources.