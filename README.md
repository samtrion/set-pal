# Description
Script for automated placement of the Microsoft PartnerId in the azure user account.

This script has been run successfully on Windows systems and Azure Cloud Shell so far. Linux systems and MacOS systems are theoretically also executable, but without guarantee.

## How to execute on Windows
1. Download `set-pal.ps1` file
2. Open PowerShell Console
3. Navigate to the download directory
4. Execute command `.\set-pal.ps1 -partnerId <PartnerId> -partnerTenantId <AzureTenantId>`
5. Follow instructions of the console output

### Known source of error
- On some systems the script cannot be executed without further ado, for this the ExecutionPolicy must be checked first. Here please execute the following command `Get-ExecutionPolicy -Scope CurrentUser`. If the result is not `Unrestricted`, you have to execute the command `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted` before executing the script.

## How to execute on Azure Portal Cloud Shell
1. Upload `set-pal.ps1` file to cloud shell
2. Execute command `.\set-pal.ps1 -partnerId <PartnerId> -partnerTenantId <AzureTenantId>`
3. Follow instructions of the console output

# 
