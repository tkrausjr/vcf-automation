Download the Supervisor Services manifest yaml and save them in the current directoy. For the automation to work, the files should all start with the `supsvc-`.

### Right now we have LCI and ArgoCD Supervisor Service included in this directory.

To run  the registration and installation on the Supervisor make sure the add-supsvc.sh file is Executable.

After this you must create a .env file in the same directory you are running the script from.

```bash
cd ~/github/vcf-automation/bash-curl/install-supervisor-services/
vi ./.env
  VCENTER_HOSTNAME="your-vc-hostname-or-ip"
  VCENTER_USERNAME="your-vc-username"
  VCENTER_PASSWORD="your-vc-password"

./add-supsvc.sh
```
