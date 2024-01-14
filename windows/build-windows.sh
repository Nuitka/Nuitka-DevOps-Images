#!/bin/sh

set -x
cd "$(dirname "$0")"

subscriptionID=$(az account show --query id --output tsv)

sigResourceGroup=DevOps-rg

location=EastUS
location2=EastUS2

sigName=DevOps_images
imageDefName=NuitkaWindowsDevOps
runOutputName=NuitkaWindowsDevOps

identityName=aibBuiUserId

# Get the identity ID
imgBuilderCliId=$(az identity show -g $sigResourceGroup -n $identityName --query clientId -o tsv)

# Get the user identity URI that's needed for the template
imgBuilderId=/subscriptions/$subscriptionID/resourcegroups/$sigResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$identityName

cp NuitkaDevOpsWindowsImage.json NuitkaDevOpsWindowsImage_tmp.json

sed -i -e "s/<subscriptionID>/$subscriptionID/g" NuitkaDevOpsWindowsImage_tmp.json
sed -i -e "s/<rgName>/$sigResourceGroup/g" NuitkaDevOpsWindowsImage_tmp.json
sed -i -e "s/<imageDefName>/$imageDefName/g" NuitkaDevOpsWindowsImage_tmp.json
sed -i -e "s/<sharedImageGalName>/$sigName/g" NuitkaDevOpsWindowsImage_tmp.json
sed -i -e "s/<region1>/$location/g" NuitkaDevOpsWindowsImage_tmp.json
sed -i -e "s/<region2>/$location2/g" NuitkaDevOpsWindowsImage_tmp.json
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
