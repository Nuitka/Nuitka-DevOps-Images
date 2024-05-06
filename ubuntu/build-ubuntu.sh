#!/bin/bash

set -x
cd "$(dirname "$0")"

subscriptionID=$(az account show --query id --output tsv)

sigResourceGroup=DevOps-rg

location=EastUS
location2=EastUS2

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
sed -i -e "s/<region2>/$location2/g" NuitkaDevOpsUbuntuImage_tmp.json
sed -i -e "s/<runOutputName>/$runOutputName/g" NuitkaDevOpsUbuntuImage_tmp.json
sed -i -e "s%<imgBuilderId>%$imgBuilderId%g" NuitkaDevOpsUbuntuImage_tmp.json

imageName=NuitkaDevOpsUbuntuImage$(date +'%s')

az resource create \
    --resource-group $sigResourceGroup \
    --properties @NuitkaDevOpsUbuntuImage_tmp.json \
    --is-full-object \
    --resource-type Microsoft.VirtualMachineImages/imageTemplates \
    -n $imageName

echo "Running image builder."

az resource invoke-action \
     --resource-group $sigResourceGroup \
     --resource-type  Microsoft.VirtualMachineImages/imageTemplates \
     -n $imageName \
     --action Run > out.txt 2>&1 &

pid=$!

trap "kill $pid 2> /dev/null" EXIT

# While copy is running...
while kill -0 $pid 2> /dev/null; do
    sleep 15

    echo "Checking login"
    az account list --refresh
done

# Disable the trap on a normal exit.
trap - EXIT

logLocation=$(cat out.txt | sed -nE 's/^.+Packer build logs are at location (.+)\. Please navigate.+$/\1/p')

exitcode=0

if [ ! -z "$logLocation" ]; then
    storageAccount=$(echo $logLocation | cut -d / -f 9)
    logPath=$(echo $logLocation | cut -d / -f 14-)

    exitcode=1

    az storage blob download -f output.txt --account-name $storageAccount --container-name packerlogs --name $logPath

    cat output.txt
fi

az resource delete \
    --resource-group $sigResourceGroup \
    --resource-type Microsoft.VirtualMachineImages/imageTemplates \
    -n $imageName

exit $exitcode
