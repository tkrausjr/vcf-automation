#!/usr/bin/bash

###################################################
# Enter temp variables here
###################################################

VCENTER_VERSION=9
HEADER_CONTENTTYPE="Content-Type: application/json"
SUPERVISOR_VIP=10.1.0.6

###################################################
# Import .env Shell Variables
# Obtain sensitive information from .env file in the folder where script will run
###################################################
if [ -f .env ]; then  # Automatically export all variables defined in .env
  set -a
    source .env
	  set +a
	  fi
	  echo "Your Target vCenter is: $VCENTER_HOSTNAME"

###################################################

################################################
# 0 - Login to VCenter and get Session ID
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
SUPERVISOR_ID=$(curl -sk -X GET https://${VCENTER_HOSTNAME}/api/vcenter/namespace-management/supervisors/summaries -H "${HEADER_SESSIONID}" -H 'Content-Type: application/json' | jq -r '.items[0].supervisor')
echo $SUPERVISOR_ID
# TODO - Find way to return Supervisor Control Plane (LB VIP) to use wqith VCF CLI.
#curl -k -X GET https://${VCENTER_HOSTNAME}/api/vcenter/namespace-management/supervisors -H "${HEADER_SESSIONID}" -H 'Content-Type: application/json' | jq -r '.'

# Below Temporary Exclusion of Supervisor Services code to test vSphere Namespace addition
# : <<'COMMENT'
################################################
# 1 - Adding Supervisor Services to vCenter

echo "Adding Supervisor Services to vCenter.."
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

################################################
# 2 - Adding new Supervisor Services to the Supervisor
echo "Setting up LCI on Supervisor"
# Reference - https://developer.broadcom.com/xapis/vsphere-automation-api/latest/api/vcenter/namespace-management/supervisors/supervisor/supervisor-services/post/
LCI_SERVICE_SPEC='{"supervisor_service": "cci-ns.vmware.com","version": "9.0.1+1815f87b"}'
echo $LCI_SERVICE_SPEC
curl -k -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "${LCI_SERVICE_SPEC}" https://${VCENTER_HOSTNAME}/api/vcenter/namespace-management/supervisors/${SUPERVISOR_ID}/supervisor-services

echo "Setting up ArgoCD on Supervisor"
# Reference - https://developer.broadcom.com/xapis/vsphere-automation-api/latest/api/vcenter/namespace-management/supervisors/supervisor/supervisor-services/post/
ARGO_SERVICE_SPEC='{"supervisor_service": "argocd-service.vsphere.vmware.com","version": "1.1.0-25100889"}'
echo $ARGO_SERVICE_SPEC
curl -k -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "${ARGO_SERVICE_SPEC}" https://${VCENTER_HOSTNAME}/api/vcenter/namespace-management/supervisors/${SUPERVISOR_ID}/supervisor-services

echo "Setting up Secret Store SVC on Supervisor"
# Reference - https://developer.broadcom.com/xapis/vsphere-automation-api/latest/api/vcenter/namespace-management/supervisors/supervisor/supervisor-services/post/
# Not Working is to modify configuration of the Supervisor version of the service like below specifying storage class
#SECRET_SERVICE_SPEC='{"supervisor_service": "secret-store.vsphere.vmware.com","version": "9.1.0+25367485", "statefulSet": "storageClassName": "cluster-wld01-01a-vsan-storage-policy"}'
SECRET_SERVICE_SPEC='{"supervisor_service": "secret-store.vsphere.vmware.com","version": "9.1.0+25367485"}'
echo $SECRET_SERVICE_SPEC
curl -k -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "${SECRET_SERVICE_SPEC}" https://${VCENTER_HOSTNAME}/api/vcenter/namespace-management/supervisors/${SUPERVISOR_ID}/supervisor-services

echo "Sleeping 45 seconds for Supervisor Services Operators and webhooks to come online ..."
sleep 40

#COMMENT
# Above TEMPORARY for debugging to comment out all Supervisor Services 
###################################################
echo -e "\n Listing Supervisor Services"
SUP_SVCS=$(curl -sk -X GET -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" https://${VCENTER_HOSTNAME}/api/vcenter/namespace-management/supervisor-services)
echo "$SUP_SVCS"

rm -f temp_final.json

###################################################
## 3 - List Namespaces
VSPHERE_NAMESPACES=$(curl -sk -X GET -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" https://${VCENTER_HOSTNAME}/api/vcenter/namespaces/instances/v2)
#echo -e "\n Listing current vSphere Namespaces by Name. \n"
#echo "$VSPHERE_NAMESPACES" | jq -r '.[].namespace'
#echo -e "\n Listing current vSphere Namespaces Raw. \n$VSPHERE_NAMESPACES"

###################################################
## 4 - Create Namespaces
# REF https://ask-vcf-services.broadcom.net/c/97a9c9a6-540f-4ac8-9dc2-f8f3db989dfc
# Doc Ref https://developer.broadcom.com/xapis/vsphere-automation-api/latest/api/vcenter/namespaces/instances/v2/post/
NAMESPACE_CREATION_SPEC='{"supervisor":"7ade15cd-1efa-4b27-92b2-2951fb4f7c87","namespace":"shared-svcs","content_libraries": [{ "content_library": "5d131c06-2446-4647-bf04-e6276ebbeb37"}]}'
NAMESPACES_MESSAGE=$(curl -sk -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "${NAMESPACE_CREATION_SPEC}" https://${VCENTER_HOSTNAME}/api/vcenter/namespaces/instances/v2 | jq -r '.messages.[].default_message')
NAMESPACES_STATUS=$(curl -sk -w '%{http_code}' --output /dev/null -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "${NAMESPACE_CREATION_SPEC}" https://${VCENTER_HOSTNAME}/api/vcenter/namespaces/instances/v2)

echo -e "\nNew vSphere Namespace Creation status: $NAMESPACES_STATUS" 
echo -e "New vSphere Namespace Creation Message: $NAMESPACES_MESSAGE" 

###################################################
## 5 - List Namespaces again to check for newly create namespace
VSPHERE_NAMESPACES=$(curl -sk -X GET -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" https://${VCENTER_HOSTNAME}/api/vcenter/namespaces/instances/v2)
#echo -e "\n Listing current vSphere Namespaces by Name. \n"
# echo "$VSPHERE_NAMESPACES" | jq -r '.[].namespace'

###################################################
## 6. VCF CLI Setup ---
echo "\nPre-configuring VCF CLI (EULA, CEIP, and plugins)..."
export VCF_CLI_VSPHERE_PASSWORD=$VCENTER_PASSWORD
vcf plugin sync 2>/dev/null || true
vcf telemetry update --opted-out 2>/dev/null || true

echo "Creating VCF Supervisor Context..."
vcf context create supervisor-ctx \
  --endpoint "$SUPERVISOR_VIP" \
  --username "$VCENTER_USERNAME" \
  --insecure-skip-tls-verify \
  -t kubernetes \
  --auth-type basic 2>/dev/null || echo "Context may already exist. Continuing..."

echo "Setting supervisor-ctx as current context..."
vcf context use supervisor-ctx 2>/dev/null || true

###################################################
## Testing kubectl
echo "\nTesting kubectl Authentication"
kubectl get ns 2>/dev/null

###################################################
## 7 - Adding ArgoCD Instance to the newly created vSphere Namespace
## Will need to do things with vcf CLI and then apply the manifest for ArgoCD Instance - from my VKS repo in supervisorservices directory.
kubectl apply -f argocd-instance.yaml -n shared-svcs 2>/dev/null
echo "Sleeping 60 seconds for ArgoCD Instance to come online ..."
sleep 60

# Return the ArgoCD Server LB Service VIP
#kubectl get po -n shared-svcs -ojson | jq -r '.'
ARGOCD_IP=$(kubectl get svc argocd-server -n shared-svcs -ojson | jq '.status.loadBalancer.ingress[0].ip' | tr -d '"' )
echo "ArgoCD App Service VIP is $ARGOCD_IP"

###################################################
###################################################
## 8 - Changing ArgoCD Password
## Will need to do things with vcf CLI and then apply the manifest for ArgoCD Instance - from my VKS repo in supervisorservices directory.
##  Left off HERE - Working up
