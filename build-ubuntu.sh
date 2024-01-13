#!/bin/sh

set -x

subscriptionID=$(az account show --query id --output tsv)

sigResourceGroup=DevOps-rg

location=EastUS

sigName=DevOps_images
imageDefName=NuitkaUbuntuDevOps
runOutputName=NuitkaUbuntuDevOps

identityName=aibBuiUserId

# Get the identity ID
imgBuilderCliId=$(az identity show -g $sigResourceGroup -n $identityName --query clientId -o tsv)

# Get the user identity URI that's needed for the template
imgBuilderId=/subscriptions/$subscriptionID/resourcegroups/$sigResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$identityName

cp NuitkaDevOpsUbuntuImage.json NuitkaDevOpsUbuntuImage_tmp.json

sed -i -e "s/<subscriptionID>/$subscriptionID/g" NuitkaDevOpsUbuntuImage_tmp.json
sed -i -e "s/<rgName>/$sigResourceGroup/g" NuitkaDevOpsUbuntuImage_tmp.json
sed -i -e "s/<imageDefName>/$imageDefName/g" NuitkaDevOpsUbuntuImage_tmp.json
sed -i -e "s/<sharedImageGalName>/$sigName/g" NuitkaDevOpsUbuntuImage_tmp.json
sed -i -e "s/<region1>/$location/g" NuitkaDevOpsUbuntuImage_tmp.json
sed -i -e "s/<runOutputName>/$runOutputName/g" NuitkaDevOpsUbuntuImage_tmp.json
sed -i -e "s%<imgBuilderId>%$imgBuilderId%g" NuitkaDevOpsUbuntuImage_tmp.json

imageName=NuitkaDevOpsUbuntuImage$(date +'%s')

az resource create \
    --resource-group $sigResourceGroup \
    --properties @NuitkaDevOpsUbuntuImage_tmp.json \
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
