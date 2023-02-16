# Install module
if  (-Not (Get-Module -ListAvailable -Name Az.DataFactory)){
    Install-Module -Name Az.DataFactory -Force
}

# Import module
Import-Module Az.DataFactory


# Service Principal authentication
$subscription = $env:SP_SUBSCRIPTION_ID
$ServicePrincipal = $env:SP_CLIENT_ID
$servicePrincipalKey = $env:SP_CLIENT_SECRET
$tenant = $env:SP_TENANT_ID

# Data factory & Machine learning
$ResourceGroup = $env:RG_NAME
$DataFactory = $env:ADF_NAME
$mlWorkspace = $env:ML_NAME
$LinkedServiceName = "LinkedServiceML"


# Azure Machine Learning linked service
$ml_linked_service_json = "{
    `"name`": `"AzureMLServiceLinkedService`",
    `"properties`": {
        `"type`": `"AzureMLService`",
        `"typeProperties`": {
            `"subscriptionId`": `"$subscription`",
            `"resourceGroupName`": `"$ResourceGroup`",
            `"mlWorkspaceName`": `"$mlWorkspace`",
            `"servicePrincipalId`": `"$ServicePrincipal`",
            `"servicePrincipalKey`": {
                `"value`": `"$servicePrincipalKey`",
                `"type`": `"SecureString`"
            },
            `"tenant`": `"$tenant`"
        }
    }
}"

try {
    # Create JSON
    $ml_linked_service_json > adf_ml.json

    # Connect to Azure
    Write-Output "`n[*] Performing the operation 'log in' on target 'ServicePrincipal ($ServicePrincipal)' account in environment 'AzureCloud Subscription ($subscription)'."
    $ApplicationId = "$ServicePrincipal"
    $SecuredPassword = ConvertTo-SecureString -String $servicePrincipalKey -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationId, $SecuredPassword
    Connect-AzAccount -ServicePrincipal -TenantId $tenant -Credential $Credential -Subscription $subscription

    # Check if exists linked service
    Write-Output "`n[*] Checking if linked service exists in [$DataFactory] ..."

    $AdfLinkedService = (Get-AzDataFactoryV2LinkedService -ResourceGroupName $ResourceGroup -DataFactoryName $DataFactory)
    $total = $AdfLinkedService.Count

    for ($i = 0;$i -lt $total; $i++)
    {   
        if ( $AdfLinkedService[$i].Name -eq $LinkedServiceName )
        {
            Write-Output "`n[!] Aborting: linked service [$LinkedServiceName] already exists."
            exit 
        }  
    } 

    # Create Linked Service
    Write-Output "`n[*] Creating Linked Service [$LinkedServiceName] in [$DataFactory] ..."

    New-AzDataFactoryV2LinkedService -ResourceGroupName $ResourceGroup -DataFactoryName $DataFactory -Name $LinkedServiceName -File "adf_ml.json" | Out-Null

    Write-Output "`n[+] Linked Service created [$LinkedServiceName] successfully."

    # Remove JSON
    Remove-Item adf_ml.json

    # Log out Azure
    Disconnect-AzAccount | Out-Null
    Write-Output "`n[+] Connection with Azure closed."
}
catch {
    Write-Host $_
}

