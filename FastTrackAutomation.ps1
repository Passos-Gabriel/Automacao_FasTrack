Import-Module dotenv
$envFile = "$PSScriptRoot\.env"
Load-DotEnv -Path $envFile

param (
    [Parameter(Mandatory = $true)]
    [string]$Keyword,

    [Parameter(Mandatory = $true)]
    [ValidateSet("East US 2", "Brazil South")]
    [string]$Region,

    [Parameter(Mandatory = $true)]
    [string]$AppId,

    [string]$Backup,

    [Parameter(Mandatory = $true)]
    [string]$BillingDXC,

    [Parameter(Mandatory = $true)]
    [string]$BillingEntity,

    [Parameter(Mandatory = $true)]
    [string]$BudgetClearance,

    [Parameter(Mandatory = $true)]
    [string]$CostCenter,

    [string]$CreatedBy,

    [string]$DBASupportTeam,

    [Parameter(Mandatory = $true)]
    [string]$Description,

    [Parameter(Mandatory = $true)]
    [string]$LGPD,

    [string]$EndDate,

    [string]$PPM,

    [Parameter(Mandatory = $true)]
    [string]$ResponsibleApp,

    [string]$ResponsibleInfra,

    [Parameter(Mandatory = $true)]
    [string]$SelfManaged,

    [Parameter(Mandatory = $true)]
    [string]$Status,

    [Parameter(Mandatory = $true)]
    [string]$Support,

    [string]$TransitionStatus
)


# Mapear região normalizada para uso com Azure CLI
switch ($Region) {
    "East US 2"     { $RegionNormalized = "eastus2" }
    "Brazil South"  { $RegionNormalized = "brazilsouth" }
    default {
        Write-Error "Região inválida. Utilize apenas 'East US 2' ou 'Brazil South'."
        exit
    }
}

# Sub
$subs = @{
    "DEV" = $env:SUB_DEV
    "QAS" = $env:SUB_QAS
    "PRD" = $env:SUB_PRD
}

$networkSubs = $subs
$environments = @("DEV", "QAS", "PRD")
foreach ($env in $environments) {
    Write-Host "`n--- Criando recursos para o ambiente: $env ---`n"

    $tags = @{
        "AppId" = $AppId
        "Backup" = $Backup
        "Billing DXC" = $BillingDXC
        "Billing Entity" = $BillingEntity
        "BudgetClearance" = $BudgetClearance
        "Cost Center" = $CostCenter
        "Created By" = $CreatedBy
        "DBA Support Team" = $DBASupportTeam
        "Description" = $Description
        "LGPD" = $LGPD
        "End Date" = $EndDate
        "PPM" = $PPM
        "Responsible - App" = $ResponsibleApp
        "Responsible - Infra" = $ResponsibleInfra
        "Self-Managed" = $SelfManaged
        "Status" = $Status
        "Support" = $Support
        "Transition Status" = $TransitionStatus
        "Workload Type" = $env
    }

    $subId = $subs[$env]
    Set-AzContext -SubscriptionId $subId

    $rgName = "rg-$Keyword-$($env.ToLower())"
    New-AzResourceGroup -Name $rgName -Location $Region -Tag $tags

    # Criar Storage Account
    $storageName = "st$($Keyword.ToLower())001$($env.ToLower())"
    New-AzStorageAccount -ResourceGroupName $rgName -Name $storageName -Location $Region -SkuName Standard_LRS -Kind StorageV2 -EnableHierarchicalNamespace $false -MinimumTlsVersion TLS1_2 -AllowBlobPublicAccess $false -PublicNetworkAccess Disabled

    # Criar Key Vault
    $kvName = "kv-$($Keyword.ToLower())-001-$($env.ToLower())"
    New-AzKeyVault -Name $kvName -ResourceGroupName $rgName -Location $RegionNormalized -PublicNetworkAccess "Disabled"

    # Criar SP
    $spName = "sp-$($Keyword.ToLower())-001-$($env.ToLower())"
    $sp = New-AzADServicePrincipal -DisplayName $spName -Scope "/subscriptions/$subId/resourceGroups/$rgName"
    Start-Sleep -Seconds 5
    $sp
    $spId = $sp.Id

    Add-AzADGroupMember -TargetGroupObjectId $env:GROUP_NETWORK_ID -MemberObjectId $spId

    New-AzRoleAssignment -ObjectId $spId -RoleDefinitionName "IaC-Contributor" -Scope "/subscriptions/$subId/resourceGroups/$rgName"
    New-AzRoleAssignment -ObjectId $spId -RoleDefinitionName "Storage Blob Data Contributor" -Scope "/subscriptions/$subId/resourceGroups/$rgName"
    New-AzRoleAssignment -ObjectId $spId -RoleDefinitionName "IaC-Network-Contributor" -Scope "/subscriptions/$($networkSubs[$env.ToLower()])/resourceGroups/rg-network"

    # Grupos
    $groupSuffixes = @("ApplicationOwner", "DevLead", "Readers", "Support", "TechLead", "ElevatedAcsTechLead", "ElevatedAcsSupport", "IaCDeveloper", "IaCSupport", "IaCSupportApprover")

    foreach ($suffix in $groupSuffixes) {
        $groupName = "GRP-AZU-$($Keyword.ToUpper())-App-$suffix"
        $mailNickname = $groupName -replace '[^a-zA-Z0-9]', ''  # Remove caracteres inválidos
        $group = Get-AzADGroup -DisplayName $groupName -ErrorAction SilentlyContinue
        if (-not $group) {
            $group = New-AzADGroup -DisplayName $groupName -MailNickname $mailNickname
            Start-Sleep -Seconds 5
        }
        $groupId = $group.Id

        $scope = "/subscriptions/$subId/resourceGroups/$rgName"

        #Permissões
        if ($suffix -eq "Readers") {
            foreach ($role in @("Reader", "Monitoring Reader", "Cost Management Reader")) {
                New-AzRoleAssignment -ObjectId $groupId -RoleDefinitionName $role -Scope $scope
            }
            New-AzRoleAssignment -ObjectId $groupId -RoleDefinitionName "[Vale] Subnet Reader" -Scope "/subscriptions/$($networkSubs[$env.ToLower()])/resourceGroups/rg-network"
        }

        if ($suffix -eq "ApplicationOwner") {
            foreach ($role in @("Reader", "Cost Management Reader", "Cost Management Contributor", "Key Vault Administrator")) {
                New-AzRoleAssignment -ObjectId $groupId -RoleDefinitionName $role -Scope $scope
            }
        }

        if ($suffix -eq "ElevatedAcsTechLead" -and $env -eq "DEV") {
            New-AzRoleAssignment -ObjectId $groupId -RoleDefinitionName "Contributor" -Scope $scope
        }

        if ($suffix -eq "ElevatedAcsSupport" -and ($env -eq "QAS" -or $env -eq "PRD")) {
            New-AzRoleAssignment -ObjectId $groupId -RoleDefinitionName "Contributor" -Scope $scope
        }

    }
    Write-Host "`n================= FIM =================" -ForegroundColor Cyan
}
