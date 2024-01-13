#!/bin/sh

set -x

subscriptionID=$(az account show --query id --output tsv)

sigResourceGroup=DevOps-rg

location=EastUS

sigName=DevOps_images
imageDefName=NuitkaWindowsDevOps
runOutputName=NuitkaWindowsDevOps

# Create user-assigned identity for VM Image Builder to access the storage account where the script is stored
identityName=aibBuiUserId$(date +'%s')
az identity create -g $sigResourceGroup -n $identityName

# Get the identity ID
imgBuilderCliId=$(az identity show -g $sigResourceGroup -n $identityName --query clientId -o tsv)

# Get the user identity URI that's needed for the template
imgBuilderId=/subscriptions/$subscriptionID/resourcegroups/$sigResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$identityName

# Download an Azure role-definition template, and update the template with the parameters that were specified earlier
curl https://raw.githubusercontent.com/Azure/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json -o aibRoleImageCreation.json

imageRoleDefName="Azure Image Builder Image Def"$(date +'%s')

# Update the definition
sed -i -e "s/<subscriptionID>/$subscriptionID/g" aibRoleImageCreation.json
sed -i -e "s/<rgName>/$sigResourceGroup/g" aibRoleImageCreation.json
sed -i -e "s/Azure Image Builder Service Image Creation Role/$imageRoleDefName/g" aibRoleImageCreation.json

# Create role definitions
az role definition create --role-definition ./aibRoleImageCreation.json

# Grant a role definition to the user-assigned identity
az role assignment create \
    --assignee $imgBuilderCliId \
    --role "$imageRoleDefName" \
    --scope /subscriptions/$subscriptionID/resourceGroups/$sigResourceGroup

cp NuitkaDevOpsWindowsImage.json NuitkaDevOpsWindowsImage_tmp.json

sed -i -e "s/<subscriptionID>/$subscriptionID/g" NuitkaDevOpsWindowsImage_tmp.json
sed -i -e "s/<rgName>/$sigResourceGroup/g" NuitkaDevOpsWindowsImage_tmp.json
sed -i -e "s/<imageDefName>/$imageDefName/g" NuitkaDevOpsWindowsImage_tmp.json
sed -i -e "s/<sharedImageGalName>/$sigName/g" NuitkaDevOpsWindowsImage_tmp.json
sed -i -e "s/<region1>/$location/g" NuitkaDevOpsWindowsImage_tmp.json
sed -i -e "s/<runOutputName>/$runOutputName/g" NuitkaDevOpsWindowsImage_tmp.json
sed -i -e "s%<imgBuilderId>%$imgBuilderId%g" NuitkaDevOpsWindowsImage_tmp.json

imageName=NuitkaDevOpsWindowsImage$(date +'%s')

az resource create \
    --resource-group $sigResourceGroup \
    --properties @NuitkaDevOpsWindowsImage_tmp.json \
    --is-full-object \
    --resource-type Microsoft.VirtualMachineImages/imageTemplates \
    -n $imageName

az resource invoke-action \
     --resource-group $sigResourceGroup \
     --resource-type  Microsoft.VirtualMachineImages/imageTemplates \
     -n $imageName \
     --action Run

sleep 10

az resource delete \
    --resource-group $sigResourceGroup \
    --resource-type Microsoft.VirtualMachineImages/imageTemplates \
    -n $imageName

az role assignment delete \
    --assignee $imgBuilderCliId \
    --role "$imageRoleDefName" \
    --scope /subscriptions/$subscriptionID/resourceGroups/$sigResourceGroup

az role definition delete --name "$imageRoleDefName"

az identity delete --ids $imgBuilderId
