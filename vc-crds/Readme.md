# Steps to add Supervisor Services
vcf context create supervisor -e 10.1.0.6 -u administrator@wld.sso --insecure-skip-tls-verify --auth-type basic
    Enter password
kubectx supervisor
k get supervisorservices -A
NOTE: Nothing returned (presumably because Core 3 supervisor Services are not listed)
NOTE: Even after adding Supervisor Services (Under vSphere UI) by uploading Service Definition YAML, but before putting them on the Supervisor nothing is listed.
k get supervisorservices -A
    No resources found
Now I went to Local Consumption Interface Service and Added it to the "supervisor" supervisor (No YAML Config Needed)
Never shows up with the following k get supervisorservices -A (Nothing does) Looking at YAML definition for the Services they are just Packages. So Supervisor Services are just Carvel Packages installed into a vSphere Namespace instead of into a cluster.
When you install LCI via UI and add it to the Supervisor you can find it with the following
k get package -A | grep cci
vmware-system-supervisor-services   cci-ns.vmware.com.9.0.2+f943fb89                                          cci-ns.vmware.com                                    9.0.2+f943fb89                         20m29s
 
vcf package installed list -n vmware-system-supervisor-services

  NAME                                        PACKAGE-NAME                            PACKAGE-VERSION          STATUS               
  kube-state-metrics                          kube-state-metrics.vsphere.vmware.com   2.9.2-24524707           Reconcile succeeded  
  svc-cci-ns.vmware.com                       cci-ns.vmware.com                       9.0.1+1815f87b           Reconcile succeeded  
  svc-harbor.tanzu.vmware.com                 harbor.tanzu.vmware.com                 2.13.1+vmware.1-vks.1    Reconcile succeeded  
  svc-supervisor-management-proxy.vmware.com  supervisor-management-proxy.vmware.com  0.4.0                    Reconcile succeeded  
  svc-tkg.vsphere.vmware.com                  tkg.vsphere.vmware.com                  3.6.0+v1.35              Reconcile succeeded  
  svc-velero.vsphere.vmware.com               velero.vsphere.vmware.com               1.8.0-embedded+24668882  Reconcile succeeded 

vcf package install svc-cci-ns.vmware.com -p cci-ns.vmware.com --values-file /home/holuser/Downloads/lci-svs-9.0.1.yaml -n vmware-system-supervisor-services

12:10:17PM: Version constraint defaulted to '>= 0.0.0'. Use the '--version'
                 flag to lock to a non-latest version.


12:10:17PM: Creating service account 'svc-cci-ns.vmware.com-vmware-system-supervisor-services-sa'
Error: serviceaccounts is forbidden: User "sso:Administrator@wld.sso" cannot create resource "serviceaccounts" in API group "" in the namespace "vmware-system-supervisor-services"

/usr/lib/vmware-wcp/decryptK8Pwd.py 
Read key from file
Connected to PSQL
Cluster: domain-c10:84953890-6288-4dd6-9ca8-d6f7572cdb29
IP: 10.1.1.85
PWD: rAV&C[D=z|9>?iNC
------------------------------------------------------------


