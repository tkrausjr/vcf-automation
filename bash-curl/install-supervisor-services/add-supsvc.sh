#!/usr/bin/bash

###################################################
# Enter temp variables here
###################################################

VCENTER_VERSION=9
VCENTER_HOSTNAME=vc-wld01-a.site-a.vcf.lab
VCENTER_USERNAME=administrator@wld.sso
VCENTER_PASSWORD='VMware123!VMware123!'

###################################################

HEADER_CONTENTTYPE="Content-Type: application/json"
################################################

# Login to VCenter and get Session ID
###############################################
SESSION_ID=$(curl -sk -X POST https://${VCENTER_HOSTNAME}/rest/com/vmware/cis/session --user ${VCENTER_USERNAME}:${VCENTER_PASSWORD} |jq -r '.value')
if [ -z "${SESSION_ID}" ]
then
	echo "Error: Could not connect to the VCenter. Please validate!!"
	exit 1
fi
echo Authenticated successfully to VC with Session ID - ${SESSION_ID} ...
HEADER_SESSIONID="vmware-api-session-id: ${SESSION_ID}"

echo "Getting Supervisor ID"
SUPERVISOR_ID=$(curl -sk -X GET 'https://vc-wld01-a.site-a.vcf.lab/api/vcenter/namespace-management/supervisors/summaries' -H "${HEADER_SESSIONID}" -H 'Content-Type: application/json' | jq -r '.items[0].supervisor')
echo $SUPERVISOR_ID

read -p "Press [Enter] to continue . . . "

for filename in supsvc-*.*ml; do

	echo "Processing file - ${filename} ..."

	#SUP_SVC_NAME=`${filename} -w0`
	#echo $SUP_SVC_NAME
	export FILE_CONTENT=`base64 ${filename} -w0`
	#echo $FILE_CONTENT

	envsubst < carvel-spec.json > temp_final.json

	echo "Adding Supervisor Service to ${VCENTER_HOSTNAME}  ..."
	curl -ks -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "@temp_final.json" https://${VCENTER_HOSTNAME}/api/vcenter/namespace-management/supervisor-services
done
echo "Sleeping 10 seconds..."
sleep 10
echo "Setting up LCI on Supervisor"
# Reference - https://developer.broadcom.com/xapis/vsphere-automation-api/latest/api/vcenter/namespace-management/supervisors/supervisor/supervisor-services/post/
LCI_SERVICE_SPEC='{"supervisor_service": "cci-ns.vmware.com","version": "9.0.1+1815f87b"}'
echo $LCI_SERVICE_SPEC
curl -k -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "${LCI_SERVICE_SPEC}" https://${VCENTER_HOSTNAME}/api/vcenter/namespace-management/supervisors/${SUPERVISOR_ID}/supervisor-services

# PLACEHOLDER For ARGOCD - Same thing we did with LCI Above
#echo "Setting up ArgoCD on Supervisor"
# Reference - https://developer.broadcom.com/xapis/vsphere-automation-api/latest/api/vcenter/namespace-management/supervisors/supervisor/supervisor-services/post/
#ARGO_SERVICE_SPEC='{"supervisor_service": "cci-ns.vmware.com","version": "9.0.1+1815f87b"}'
#echo $ARGO_SERVICE_SPEC
#curl -k -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "${LCI_SERVICE_SPEC}" https://${VCENTER_HOSTNAME}/api/vcenter/namespace-management/supervisors/${SUPERVISOR_ID}/supervisor-services


echo "\n Listing Supervisor Services"
SUP_SVCS=$(curl -sk -X GET -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" https://${VCENTER_HOSTNAME}/api/vcenter/namespace-management/supervisor-services)
echo "$SUP_SVCS"

# rm -f temp_final.json