import requests
import urllib3
from vmware.vapi.vsphere.client import create_vsphere_client
session = requests.session()
session.verify = False
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
vsphere_client = create_vsphere_client(server='https://vc-wld01-a.site-a.vcf.lab',
  username='administrator@wld.sso', password='VMware123!VMware123!', session=session)
vsphere_client.vcenter.VM.list()