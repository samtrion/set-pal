[CmdletBinding()]
param (
    # Microsoft Partner Id
    [Parameter(Mandatory = $true)]
    [string]
    $partnerId,

    # Azure Tenant Id - Home Tenant
    [Parameter(Mandatory = $true)]
    [guid]
    $partnerTenantId
)
# Set TLS to concrete version
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

try {
    # Install NuGet PackageProvider and PackageSource, for all non developer systems
    if ((Get-PackageProvider -Name 'NuGet').Length -eq 0) {
        Install-PackageProvider -Name 'NuGet' -MinimumVersion '2.8.5.208' -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
    }
    Register-PackageSource -Name 'NuGet' -Location https://api.nuget.org/v3/index.json -ProviderName 'NuGet' -Trusted -Force -ErrorAction Stop | Out-Null

    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
}
catch {
    Write-Host "PAL: Could not install NuGet package source." -ForegroundColor Red
    exit
}

try {
    if ($PSEdition -eq 'Desktop' -or $IsWindows) {
        # Validate PowerShell Module Paths, because in some cases this path is missing.
        $modulePath = [Environment]::GetEnvironmentVariable("PSModulePath").ToString()
        $userModules = [System.IO.Path]::Combine([Environment]::GetFolderPath('MyDocuments'), "WindowsPowerShell", "Modules")
        $paths = $modulePath.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)
     
        if ($paths -notcontains $userModules) {
            $paths = (, $userModules + $paths) | Select-Object -Unique
            [Environment]::SetEnvironmentVariable("PSModulePath", [String]::Join(";", $paths))        
        }
    }
 
    # Install required Az Module, if necessary 
    if ((Get-Module -ListAvailable -Name Az.ManagementPartner).Length -eq 0) {
        Install-Module -Name Az.ManagementPartner -Scope CurrentUser -AllowClobber -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
    }
    if ((Get-Module -ListAvailable -Name Az.Accounts).Length -eq 0) {
        Install-Module -Name Az.Accounts -Scope CurrentUser -AllowClobber -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
    }
}
catch {
    Write-Host "PAL: The necessary PowerShell modules could not be installed." -ForegroundColor Red
    exit
}     

# Connect to Azure
try {    
    Az.Accounts\Clear-AzContext -Scope Process -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null

    try {
        if ($PSEdition -eq 'Core' -and ($IsLinux -or $IsMacOS)) {
            Az.Accounts\Connect-AzAccount -Scope Process -UseDeviceAuthentication -ErrorAction Stop | Out-Null
        }
        else {
            Az.Accounts\Connect-AzAccount -Scope Process -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        }
    }
    catch {
        # Fallback connect for Accounts without home tenant
        if ($PSEdition -eq 'Core' -and ($IsLinux -or $IsMacOS)) {
            Az.Accounts\Connect-AzAccount -Tenant $partnerTenantId -Scope Process -UseDeviceAuthentication -ErrorAction Stop | Out-Null
        }
        else {         
            Az.Accounts\Connect-AzAccount -Tenant $partnerTenantId -Scope Process -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        }
    }
}
catch {
    Write-Host "PAL: Could not connect to the given Azure account." -ForegroundColor Red
    exit
}

# Examine each tenant and mark with PAL 
foreach ($tenant in Az.Accounts\Get-AzTenant) {
    $tenantId = $tenant.TenantId
    $tenantName = $tenant.Name
    $partner = $null

    Write-Host "PAL: Determine partner information for tenant '$($tenantName)' (TenantId: $($tenantId))." -ForegroundColor Cyan

    try {
        try {
            Az.Accounts\Set-AzContext -Tenant $tenantId -Scope Process -WarningAction SilentlyContinue | Out-Null
            $partner = Az.ManagementPartner\Get-AzManagementPartner -ErrorAction Stop
        }
        catch {
            if ($PSEdition -eq 'Core' -and ($IsLinux -or $IsMacOS)) {
                Az.Accounts\Connect-AzAccount -Tenant $tenantId -Scope Process -UseDeviceAuthentication -ErrorAction Stop | Out-Null
            }
            else {         
                Az.Accounts\Connect-AzAccount -Tenant $tenantId -Scope Process -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
            }
        }

        if ($null -eq $partner) {
            $partner = Az.ManagementPartner\Get-AzManagementPartner -ErrorAction SilentlyContinue
        }

        if (!$partner) {
            Az.ManagementPartner\New-AzManagementPartner -PartnerId $partnerId -ErrorAction Stop | Out-Null
            Write-Host "PAL: Tenant '$($tenantName)' (TenantId: $($tenantId)) added." -ForegroundColor Green
        }
        elseif ($partner.PartnerId -ne $partnerId) {
            Az.ManagementPartner\Update-AzManagementPartner -PartnerId $partnerId -ErrorAction Stop | Out-Null
            Write-Host "PAL: Tenant '$($tenantName)' (TenantId: $($tenantId)) updated." -ForegroundColor Green
        }
        else {
            Write-Host "PAL: Tenant '$($tenantName)' (TenantId: $($tenantId)) up to date." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "PAL: PartnerId couldn't be placed in tenant '$($tenantName)' (TenantId: $($tenantId))." -ForegroundColor DarkYellow
    }
}

Write-Host "PAL: Done..." -ForegroundColor Cyan
