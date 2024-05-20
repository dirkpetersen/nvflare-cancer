# NVFlare in Cancer Research 

We are setting up a project among multiple cancer research organizations to explore federated learning using NVFlare. This is a pilot co-led by OHSU Knight Cancer Institute and NCI. We assume that the participants will have one of these options available:

- An AWS or Azure cloud account 
- An on-premises Slurm-based HPC system with GPU nodes
- A Windows laptop with a GPU and WSL Linux installed 

The central NVFlare dashboard and server was installed by the `Project Admin`, this role can be filled by the IT department of the organization that is responsible for installing the central infrastructure in a hub-and-spoke model. The researchers in this institution and other institutions will use an NVFlare compute client on their HPC system, their laptop or a separate cloud account and will have no access to the central hub while the `Project Admin` of the central hub will have no access to the data processd by the clients. Please review the [terminologies and roles](https://nvflare.readthedocs.io/en/main/user_guide/security/terminologies_and_roles.html) required for a funtioning NVFlare federation.


# Table of Contents

- [NVFlare in Cancer Research](#nvflare-in-cancer-research)
- [Table of Contents](#table-of-contents)
- [Installing NVFlare deploy environment](#installing-nvflare-deploy-environment)
  - [Prerequisites](#prerequisites)
  - [Installing the right version of Python](#installing-the-right-version-of-python)
  - [Installing NVFlare in an isolated venv](#installing-nvflare-in-an-isolated-venv)
- [Connecting to an existing NVFlare Project](#connecting-to-an-existing-nvflare-project)
  - [Using NVFlare as a Lead](#using-nvflare-as-a-lead)
    - [Using the administrative console](#using-the-administrative-console)
    - [Testing a Python example](#testing-a-python-example)
    - [Testing a Python example](#testing-a-python-example-1)
  - [Using NVFlare as an Org Admin](#using-nvflare-as-an-org-admin)
    - [Register a client site and clients](#register-a-client-site-and-clients)
    - [Install a client on AWS](#install-a-client-on-aws)
    - [Install a client on HPC](#install-a-client-on-hpc)
    - [Install a client on your WSL Laptop](#install-a-client-on-your-wsl-laptop)
    - [Verify installation](#verify-installation)
- [(Not needed right now): Deploying a new NVFlare Project](#not-needed-right-now-deploying-a-new-nvflare-project)
  - [Installing Dashboard](#installing-dashboard)
    - [Getting dashboard production ready](#getting-dashboard-production-ready)
      - [About 1. Start at reboot](#about-1-start-at-reboot)
      - [About 2. Restart on Error](#about-2-restart-on-error)
      - [About 3. DNS/HTTPS](#about-3-dnshttps)
        - [DNS and SSL Certificate through your IT department](#dns-and-ssl-certificate-through-your-it-department)
        - [DNS through Route53 and let's encrypt SSL](#dns-through-route53-and-lets-encrypt-ssl)
    - [Configuring Dashboard](#configuring-dashboard)
    - [Resetting Dashboard](#resetting-dashboard)
  - [Installing Server](#installing-server)
  - [Installing Client](#installing-client)


# Installing NVFlare deploy environment 

First we install the NVFlare software packages on a computer from which you will connect to the infrastructure and/or roll it out in the first place. This can be a laptop or management server.

## Prerequisites

If you want to roll out parts of the infrastruncture to AWS or Azure, you should have the AWS or Azure CLI installed and AWS or Azure credentials setup. You must be allowed to launch AWS EC2 instances or Azure virtual machines including network configuration.

## Installing the right version of Python

For consistency reasons we recommend installing the latest Python version supported by NVFlare (NVFlare 2.40 and Python 3.10 as of May 2024). For our AWS deployment we will use Ubuntu 22.04 (AWS image ami-03c983f9003cb9cd1, which comes with Python 3.10) instead of the default Ubuntu 20.04 (which comes with Python 3.8). To quickly install Python 3.10 in your work environment (Linux, Mac or Windows with WSL Linux) we propose the Rye Package manager by Armin Ronacher (the maker of Flask) as it very fast and can be easily removed. Below are the instructions for Linux (incl. WSL) and Mac. Do not use the Windows instructions [here](https://rye-up.com/) as they are not tested. 
Rye quickly installs Python 3.10 in a reproducible way and makes it the default Python on your system (it will edit file ~/.python-version)

```bash
curl -sSf https://rye-up.com/get | bash
. ~/.rye/env
rye fetch 3.10
rye pin 3.10
```

The Rye installer will put `. ~/.rye/env` into ~/.profile to ensure that this Python version is ready at the next login. If you have an older HPC system it may not use the file ~/.profile but ~/.bash_profile instead. just run `echo '. ~/.rye/env' >> ~/.bash_profile` in that case. 

A quick test should show, that the default python is latest Python 3.10

```bash
$ python --version
Python 3.10.14
```

## Installing NVFlare in an isolated venv

install NVFlare in a new virtual environment at `~/.local/nvf` and source it

```bash
$ rye init ~/.local/nvf && cd ~/.local/nvf && rye add nvflare && rye sync && cd ~

success: Initialized project in /home/pytester/.local/nvf
  Run `rye sync` to get started
Initializing new virtualenv in /home/pytester/.local/nvf/.venv
Python version: cpython@3.10.14
Added nvflare>=2.4.0 as regular dependency

$ source ~/.local/nvf/.venv/bin/activate
(nvf) ~$
```

if you plan to work with your NVFlare project for a while, you should consider activating it automatically each time you login, e.g. 

```bash
echo 'source ~/.local/nvf/.venv/bin/activate' >> ~/.profile  # or ~/.bash_profile for older Linux
```

Next we will be connecting to an NVFlare Dashboard that someone else set up 

# Connecting to an existing NVFlare Project

In NVFlare, before deploying a new project, you'll likely connect to an existing project that a collaborating institution's `Project Admin` has installed. Your institution will need users with different roles:

- `Lead`: The most common role, typically held by researchers. They submit jobs to the NVFlare system, which then executes the jobs on NVFlare clients (physical or virtual servers) set up by an `Org Admin`.
- `Org Admin`: Can be a researcher with an AWS or Azure cloud account, or someone who can log in as a non-root user to a server with GPUs. They are responsible for installing and managing NVFlare clients. This role can also be held by cloud or research computing administrators. `Org Admins` are not allowed to submit jobs.
- `Member`: Has read-only access to the project by default.

To ensure proper separation of duties, your institution will need at least two accounts: one with the `Org Admin` role for managing infrastructure, and another with the `Lead` role for submitting jobs.

## Using NVFlare as a Lead

`Leads` will sign up and (after approval by the Project Admin) login to the NVFlare dashboard to download authentication and configuration information. We assume the dashboard will be at `https://myproject.mydomain.edu` (your collaborators will share the actual address/URL with you). Once you have registered as a `Lead` and been approved you will be able to login to the dashboard and can download the console. 

![image](https://github.com/dirkpetersen/nvflare-cancer/assets/1427719/fd174c42-c0dc-4fe2-9525-8bfb65529a8a)

To get credentials to the NVFlare system login as `Lead` at `https://myproject.mydomain.edu` and click "Download FLARE Console" under DOWNLOADS and keep the password. The console is downloaded as a zip file called `your@email.adr.zip`. Then unzip the console to a folder in your home directory for this specific NVFlare project and enter the password

```bash
mkdir -p ~/.nvflare/myproject 
unzip -d ~/.nvflare/myproject ./my-lead\@domain.edu.zip
```
then run `~/.nvflare/myproject/my-lead@domain.edu/startup/fl_admin.sh`, enter the email address `my-lead@domain.edu` when prompted and run the command `check_status server` 


### Using the administrative console 

```
~/.nvflare/myproject/my-lead\@domain.edu/startup/fl_admin.sh

> check_status server
Engine status: stopped
---------------------
| JOB_ID | APP NAME |
---------------------
---------------------
Registered clients: 1
----------------------------------------------------------------------------
| CLIENT | TOKEN                                | LAST CONNECT TIME        |
----------------------------------------------------------------------------
| AWS-T4 | 6d49fb6b-32ec-4431-a417-bf023f85f2d0 | Mon May  6 06:28:16 2024 |
----------------------------------------------------------------------------
Done [1087332 usecs] 2024-05-05 23:28:25.033931

```

You are now connected to an NVFlare system. As a next step let's run a test job using python. We will clone the NVFlare repos into a shared project folder to use some of the standard examples

### Testing a Python example 

```
cd /shared/myproject
git clone https://github.com/NVIDIA/NVFlare
```

and then copy this python example to file fl-test.py: 

```python
#! /usr/bin/env python3

import os
import nvflare.fuel.flare_api.flare_api as nvf

flprj = "myproject"
username = "my-lead@domain.edu" 
myjob = "/shared/myproject/NVFlare/examples/hello-world/hello-numpy-sag/jobs/hello-numpy-sag"

authloc = os.path.join(os.path.expanduser("~"),
                ".nvflare", flprj, username)

sess = nvf.new_secure_session(
    username=username,
    startup_kit_location=authloc
)

print(sess.get_system_info())

# You must use an absolute path here:
job_id = sess.submit_job(myjob)
print(f"{job_id} was submitted")

sess.monitor_job(job_id, cb=nvf.basic_cb_with_print, cb_run_counter={"count":0})
```

Once you run the Python script you should see something like this:

```
$ python3 ./fl-test.py

SystemInfo
server_info:
status: stopped, start_time: Sun May  5 23:25:37 2024
client_info:
AWS-T4(last_connect_time: Wed May  8 17:14:01 2024)
job_info:

e8d1e2c9-b47f-43fb-b95a-03551c07b93f was submitted

{'name': 'hello-numpy-sag', 'resource_spec': {}, 'min_clients': 2, 'deploy_map': {'app': ['@ALL']}, 'submitter_name': 'my-lead@domain.edu', 'submitter_org': "FL site", 'submitter_role': 'lead', 'job_folder_name': 'hello-numpy-sag', 'job_id': 'e8d1e2c9-b47f-43fb-b95a-03551c07b93f', 'submit_time': 1715213649.985026, 'submit_time_iso': '2024-05-09T00:14:09.985026+00:00', 'start_time': '', 'duration': 'N/A', 'status': 'SUBMITTED'}
```

### Testing a Python example


## Using NVFlare as an Org Admin

### Register a client site and clients 

If you are the `Org Admin` of a collaborating organization, you join by signing up at `https://myproject.mydomain.edu` with your email address, Name and password. In a second step you are asked to enter your Organization name. Pick `Org Admin` as your role before you add one or more client sites with number of GPUs and memory per GPU. Here you describe the computers with GPUs that you can access to install NVFlare clients. Give them self-explanatory client site names, for example if your site is a single Windows Laptop with an RTX-3080 GPU you may call it WSL-RTX3080. If you have an HPC system with A40 GPUs, call one client site HPC-A40.
For AWS, lets register a client site with a single T4 GPU with 16GB memory, e.g. AWS-T4 (as of May 2024, the lowest cost instance type with a T4 is g4dn.xlarge, also there is a bug in NVFlare and you can only enter 15GB instead of 16GB memory.) 


### Install a client on AWS 

Login as `Org Admin` at `https://myproject.mydomain.edu` and under DOWNLOADS -> Client Sites -> AWS-T4 click "Download Startup Kit" and keep the password.

Move the file to the location where you launched the console install earlier, unzip the server startup kit and enter the password

```bash
unzip AWS-T4.zip 
cd AWS-T4
```

follow [these instructions to install the client on AWS](https://nvflare.readthedocs.io/en/main/real_world_fl/cloud_deployment.html#deploy-fl-client-on-aws) or execute this command: 

```bash
startup/start.sh --cloud aws     # this is only needed for full automation: --config my_config.txt
```

then you get 3 questions asked, and instead of the default AMI (Ubuntu 20.04) you pick the slightly newer 22.04 (ami-03c983f9003cb9cd1) and you also pick a relatively low cost AWS instance with a T4 GPU, for example g4dn.xlarge. If you are running just a first test, it is fine to install the default and low cost t2.small instance.


```
Cloud AMI image, press ENTER to accept default ami-04bad3c587fe60d89: ami-03c983f9003cb9cd1
Cloud EC2 type, press ENTER to accept default t2.small: g4dn.xlarge
Cloud EC2 region, press ENTER to accept default us-west-2:
region = us-west-2, ami image = ami-03c983f9003cb9cd1, EC2 type = g4dn.xlarge, OK? (Y/n) y
If the client requires additional dependencies, please copy the requirements.txt to AWS-T4/startup/
Press ENTER when it's done or no additional dependencies.
```

The output should be similar to this :

```
Generating key pair for VM
Creating VM at region us-west-2, may take a few minutes.
VM created with IP address: 54.xxx.xxx.x
Copying files to nvflare_client
Destination folder is ubuntu@54.xxx.xxx.x:/var/tmp/cloud
Installing packages in nvflare_client, may take a few minutes.
System was provisioned
To terminate the EC2 instance, run the following command.
aws ec2 terminate-instances --instance-ids i-0673318fd1ed204f0
Other resources provisioned
security group: nvflare_client_sg_20293
key pair: NVFlareClientKeyPair
```

Now try logging in :

```bash
ssh -i NVFlareClientKeyPair.pem ubuntu@54.xxx.xxx.x
```

add a cronjob to ensure that the client will restart after a reboot

```bash
(crontab -l 2>/dev/null; echo "@reboot  /var/tmp/cloud/startup/start.sh >> /var/tmp/nvflare-client-start.log 2>&1") | crontab
```

Make sure the newest GPU drivers and other packages are installed:

```bash
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y nvidia-driver-535 nvidia-utils-535
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
sudo reboot 
```

### Install a client on HPC 

Login as `Org Admin` at `https://myproject.mydomain.edu` and under DOWNLOADS -> Client Sites -> HPC-A40 click "Download Startup Kit" and keep the password.

Move the file to the location where you launched the console install earlier, unzip the server startup kit and enter the password

```bash
unzip HPC-A40.zip 
cd HPC-A40
```

Most HPC systems will use the Slurm workload manager these days. On such a system we don't require the overhead of a container or even a virtual machine that needs to be installed. If our HPC admin allows, we can simply submit a batch job that will launch our NVFlare client. In this case we assume that the HPC admin has made A40 GPUs available as general resource (GRES) named gpu:a40 (`--gres gpu:a40`) and we want a single GPU (`--gres gpu:a40:1`). Let's create a little shell script called `nvflare-HPC-A40.sub` that functions as Slurm batch script:

```bash
#! /bin/bash
#SBATCH --job-name "NVFlare Client"
#SBATCH --time 1-00:00:00  # one day
#SBATCH --gres gpu:a40:1
#SBATCH --output nvflare-HPC-A40.out
#SBATCH --error nvflare-HPC-A40.err

folder=$(pwd)
source ~/.local/nvf/.venv/bin/activate
python -u -m nvflare.private.fed.app.client.client_train -m $folder -s fed_client.json --set uid=HPC-A40 secure_train=true config_folder=config org=Test
```

As you can see we run the nvflare.private.fed.app.client.client_train python module with the HPC-A40 configuration in an Organization named "Test" 

Now let's run this script in the HPC-A40 folder and then use the `tail -f` command to show the output file in real time. 

```
$ sbatch nvflare-HPC-A40.sub
Submitted batch job 424459530

tail -f nvflare-HPC-A40.out
```

If the output file does not exist, the job has not started yet. In that case run the `squeue --me` command to check the reason why your job may not have started yet. If you find squeue a bit complicated, you can simply use `tsqueue` after installing the [slurm-gui Python Package](https://pypi.org/project/slurm-gui). 

There are a few considerations when running NVFlare on an HPC Cluster:

- You need to determine how long a job you submitted will be allowed to run. In this example we assume that the job can run for 1 day but the policies at your site may be different
- Most HPC nodes need to allocate a GPU exclusively for the duration of the job. We need to understand that NVFlare client will wait for jobs while a GPU is already allocated which means that the GPU will be idle most times
- HPC systems using Slurm >=22.05 have the ability to share GPUs across multiple jobs. You can ask your HPC Admin to enable [Slurm GPU Sharding](https://slurm.schedmd.com/gres.html#Sharding) to increase the efficiency of the HPC cluster.

### Install a client on your WSL Laptop

To run NVFlare on WSL Linux, you need an NVidia GPU in your Laptop and Windows 11 or a qualifying version of Windows 10. Please [see details here](https://learn.microsoft.com/en-us/windows/ai/directml/gpu-cuda-in-wsl).

Login as `Org Admin` at `https://myproject.mydomain.edu` and under DOWNLOADS -> Client Sites -> WSL-RTX3080 click "Download Startup Kit" and keep the password.

Move the file to the location where you launched the console install earlier, unzip the server startup kit and enter the password

```bash
unzip WSL-RTX3080.zip 
cd WSL-RTX3080
startup/start.sh
```

### Verify installation 

Finally we want to check if all components are working together. We will use the [fl_admin.sh script](https://nvflare.readthedocs.io/en/main/real_world_fl/operation.html#operating-nvflare) for this. The script is available in each of the different FLARE Console packages. They contains different credentials for each user that downloads this package. 

To check the server status, login as `Project Admin` or `Org Admin` at https://myproject.mydomain.edu and click "Download FLARE Console" under DOWNLOADS and keep the passsword. 

move the file to the location where you launched the console install earlier, unzip the server startup kit and enter the password

```bash
unzip orgadm\@domain.edu.zip 
cd orgadm\@domain.edu
```

then run startup, enter the email address of the user and run `check_status server` and/or `check_status client`

```
startup/fl_admin.sh

> check_status server
Engine status: stopped
---------------------
| JOB_ID | APP NAME |
---------------------
---------------------
Registered clients: 1
----------------------------------------------------------------------------
| CLIENT | TOKEN                                | LAST CONNECT TIME        |
----------------------------------------------------------------------------
| AWS-T4 | 6d49fb6b-32ec-4431-a417-bf023f85f2d0 | Mon May  6 06:28:16 2024 |
----------------------------------------------------------------------------
Done [1087332 usecs] 2024-05-05 23:28:25.033931

> check_status client
----------------------------------------
| CLIENT | APP_NAME | JOB_ID | STATUS  |
----------------------------------------
| AWS-T4 | ?        | ?      | No Jobs |
----------------------------------------
Done [61900 usecs] 2024-05-05 23:28:34.333857
```

Once you have installed a new client as an `Org Admin` your users can connect to the system as `Lead`. Please see `Using NVFlare as a Lead`



# (Not needed right now): Deploying a new NVFlare Project

The documentation below is not required for the current project that is exploring NVFlare in cancer research, however it can be useful if you would like to install your own production level NVFlare system

## Installing Dashboard

The NVFlare dashboard will be created in an isolated AWS account. Please see these instructions to [create the dashboard on AWS](https://nvflare.readthedocs.io/en/main/real_world_fl/cloud_deployment.html#create-dashboard-on-aws) or use this command and enter the email address of the `Project Admin` when prompted.

```
nvflare dashboard --cloud aws
```

If you receive a VPC error such as (`VPCIdNotSpecified`) it means that no default network configuration ([Default VPC](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html)) has been created by your AWS administrator. Default VPCs are often used in smaller test envionments. You can create a default VPC by using this command: `aws ec2 create-default-vpc` . If that fails you may not have permission to create this and have to reach out to your AWS Administrator for a solution. In NVFlare versions > 2.4 you will also be able to pick your own VPC. 

After the dashboard is started you will see a dashboard URL that includes an IP address and looks like `http://xxx.xxx.xxx.xxx:443`. Make sure you record the email address and the 5 digit initial password that is displayed in the terminal. Verify that you can login with email address as the user and the password at that URL. You can change your password at `MY INFO -> Edit My Profile`

### Getting dashboard production ready 

Now the dashboard is installed and you would like to use it more permanently, we need to:

1. Ensure that the dashboard will be automatically started after a reboot 
1. Ensure that the dashboard is monitored and restarted on error.
1. Set up DNS/HTTPS to ensure that users don't have to connect to an ip-address insecurely.  

#### About 1. Start at reboot 

Login to the dashboard instance via ssh (using -i NVFlareDashboardKeyPair.pem)  

```bash
ssh -i "NVFlareDashboardKeyPair.pem" ubuntu@52.123.123.123
```

and run this command to add a line to the crontab file:

```bash
(crontab -l 2>/dev/null; echo "@reboot \$HOME/.local/bin/nvflare dashboard --start -f \$HOME > /var/tmp/nvflare-docker-start.log 2>&1") | crontab
```

#### About 2. Restart on Error

As in 1. login with NVFlareDashboardKeyPair.pem and create a script ~/monitor.sh as the Ubuntu user

```bash
#!/bin/bash

url="https://myproject.mydomain.edu"   # Set the website URL
search_string='name="viewport"'        # Set the search string in the HTML source
timeout_duration=15                    # Set the timeout duration in seconds
date=$(date)                           # Get the current date for logging

# Check if the search string exists in the HTML source code
if curl -k -s -m $timeout_duration $url | grep -q "$search_string"; then
    echo "${date}: OK ! The search string '$search_string' was found in the HTML source code of $url"
else
    echo "${date}: Error ! The search string '$search_string' was not found in the HTML source code of $url or the connection timed out after $timeout_duration seconds"
    # Run the commands if the search string is not found or the connection times out
    echo "${date}: Restarting NVFlare dashboard"
    $HOME/.local/bin/nvflare dashboard --stop
    sleep 3
    $HOME/.local/bin/nvflare dashboard --start -f ~
fi
```

and add it as an hourly cronjob :

```bash
(crontab -l 2>/dev/null; echo "59 * * * * \$HOME/monitor.sh >> /var/tmp/nvflare-monitor.log 2>&1") | crontab
```

#### About 3. DNS/HTTPS

Many IT departments advise their users to only log into websites that do offer secure transport (such as https/ssl). To obtain an SSL certificate we need to configure a DNS domain name that is tied to the certificate, but before we can get a DNS entry we need to create floating permanent IP addresses, (In AWS lingo this is an elastic IP address) that will be tied to the machine that runs the dashboard but can also be assinged to another machine later in case of a migration. We will create 2 floating ip addresses, one for the dashboard and the one for the server. Execute this command twice and note each ip address and allocation id.

```bash
aws ec2 allocate-address --domain vpc  # get YOUR_ALLOCATION_ID
```

Then find out the INSTANCE_ID of the instance you created and associate it with the first allocation id.

```bash
aws ec2 describe-instances #  get YOUR_INSTANCE_ID
aws ec2 associate-address --instance-id YOUR_INSTANCE_ID --allocation-id YOUR_ALLOCATION_ID
```

Then there are 2 options: In most cases you will obtain a DNS name and certificate from your IT department. For this example we assume your domain name for the dashboard `myproject.mydomain.edu` and the server is `myproject-server.mydomain.edu`. In some cases someone else may have configured the AWS DNS Service (Route 53) that allows you to manage your own DNS. If you manage your own DNS you can also easily use SSL certs from [Let's Encrypt](https://letsencrypt.org/). Let's work through both options: 

##### DNS and SSL Certificate through your IT department 

Once your DNS entries are setup and you have received your SSL cert for `myproject.mydomain.edu` from IT you can setup secure transport. In most cases you will receive a pem certificate file protected by a password. Upload that file to myproject.mydomain.edu and 

```bash
(nvf) $ scp -i "NVFlareDashboardKeyPair.pem" mycert.pem ubuntu@myproject.mydomain.edu
(nvf) $ ssh -i "NVFlareDashboardKeyPair.pem" ubuntu@myproject.mydomain.edu
```

use the openssl command to extract the x509 certificate and the key file into the ~/cert folder. Restart the container after that. On the myproject.mydomain.edu server paste in these commands:

```bash
openssl rsa -in mycert.pem -out ~/cert/web.key
openssl x509 -in mycert.pem -out ~/cert/web.crt
nvflare dashboard --stop 
nvflare dashboard --start -f ~
```

##### DNS through Route53 and let's encrypt SSL 


On your computer paste in these commands to generate the export statements for AWS credentials  

```bash
aws configure get aws_access_key_id | awk '{print "export AWS_ACCESS_KEY_ID=" $1}'
aws configure get aws_secret_access_key | awk '{print "export AWS_SECRET_ACCESS_KEY=" $1}'
aws configure get aws_session_token | awk '{print "export AWS_SESSION_TOKEN=" $1}'
```

copy these, login to the to the dashboard instance  

```bash
ssh -i "NVFlareDashboardKeyPair.pem" ubuntu@ec2-xxx-xxx-xxx-xxx.us-west-2.compute.amazonaws.com
```

and paste them into the terminal, then install the aws cli and the certbot-dns-route53 package 

```bash
python3 -m pip install awscli certbot-dns-route53
```

To register our IP address in the AWS DNS system called Route 53 we need to first get the ID of the hosted zone (which is a domain or sub domain in DNS, here MYHOSTEDZONEID) 

```bash
aws route53 list-hosted-zones
```

and then register a new hostname in this hosted zone using the aws route53 command. Replace myproject.mydomain.edu with your fully qualified domain name and 123.123.123.123 with the elastic ip address you created earlier. 

```bash
JSON53="{\"Comment\":\"DNS update\",\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"myproject.mydomain.edu\",\"Type\":\"A\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"123.123.123.123\"}]}}]}"
aws route53 change-resource-record-sets --hosted-zone-id MYHOSTEDZONEID --change-batch "${JSON53}"
```

Then we can use run certbot to connect to letsencrypt.org and create our SSL certificate and copy the files to ~/cert

```bash
certbot certonly --dns-route53 --register-unsafely-without-email --agree-tos --config-dir ~/cert --work-dir ~/cert --logs-dir ~/cert -d myproject.mydomain.edu
cp ~/cert/live/myproject.mydomain.edu/fullchain.pem ~/cert/web.crt
cp ~/cert/live/myproject.mydomain.edu/privkey.pem ~/cert/web.key
chmod 600 ~/cert/live/myproject.mydomain.edu/privkey.pem ~/cert/web.key
```

and restart the dashboard server 

```bash
nvflare dashboard --stop 
nvflare dashboard --start -f ~
```

Let's encrypt ssl certs have a reputation of high security because they expire after 90 days but can be renewed automatically. For this we simply setup a cronjob that runs monthly on the first of every month. Note it may not succeed every month as Let's encrypt does not allow renewing certs that are younger than 60 days. Run this command

```bash
(crontab -l 2>/dev/null; echo "0 0 1 * * \$HOME/.local/bin/certbot renew --config-dir \$HOME/cert --work-dir \$HOME/cert --logs-dir \$HOME/cert >> /var/tmp/certbot-renew.log 2>&1") | crontab
```

upgrade the OS and reboot the instance to verify that it will start properly after maintenance 

```bash
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
sudo reboot 
```

### Configuring Dashboard

Login to the `https://myproject.mydomain.edu` with the email address and 5 digit initial password of the project administrator and make at least the following changes: 

- At MYINFO click "Edit my Profile" and change the password of the project administrator 
- At PROJECT CONFIGURATION enter short name, title and description and click "Publish" to allow users to sign up 
- At SERVER CONFIGURATION enter `myproject-server.mydomain.edu` at "Server (DNS Name)"
- At PROJECT HOME click "Freeze Project"

After you have frozen the project you can no longer change any of the settings above, however you can still reset the entire dashboard if needed. 

### Resetting Dashboard

If you made a mistake when setting up the dashboard, for example, you froze the project but want to make changes, you can reset the dashboard by moving the datadase out of the way, without having to reinstall the dashboard server.

```bash
nvflare dashboard --stop
mv ~/db.sqlite ~/old.db.sqlite 
nvflare dashboard --start -f $HOME --cred project_adm\@mydomain.edu:mysecretpassword
```

## Installing Server

The server is a central system that is installed alongside the dashboard by the project administrator. The users from the federated sites will connect first to the dashbard to download a configuration and then install a client to build a connection to the server to exhange ML models and meta information but not share their data.

As a project admin login to the dashboard and download the server startup kit and copy the password 

![image](https://github.com/dirkpetersen/nvflare-cancer/assets/1427719/523aa5a0-7c28-4713-b629-352caa90ea4c)

move the file to the location where you launched the console install earlier, unzip the server startup kit and enter the password

```bash
unzip myproject-server.mydomain.edu.zip 
cd myproject-server.mydomain.edu 
```

follow [these instructions to install the server on AWS](https://nvflare.readthedocs.io/en/main/real_world_fl/cloud_deployment.html#deploy-fl-server-on-aws) or execute this command: 

```bash
startup/start.sh --cloud aws     # this is only needed for full automation: --config my_config.txt
```

then we are prompted, and instead the default AMI (Ubuntu 20.04) we pick the slightly newer 22.04 (ami-03c983f9003cb9cd1)

```
Cloud AMI image, press ENTER to accept default ami-04bad3c587fe60d89: ami-03c983f9003cb9cd1
Cloud EC2 type, press ENTER to accept default t2.small:
Cloud EC2 region, press ENTER to accept default us-west-2:
region = us-west-2, ami image = ami-03c983f9003cb9cd1, EC2 type = t2.small, OK? (Y/n) Y
If the server requires additional dependencies, please copy the requirements.txt to myproject-server.mydomain.edu/startup/.
Press ENTER when it's done or no additional dependencies.
```

After this you should get confirmation that `myproject-server.mydomain.edu` was installed. Then find out the INSTANCE_ID of the instance you created and associate it with the second allocation id for the elastic IP you created earlier: 

```bash
aws ec2 describe-instances #  get YOUR_INSTANCE_ID
aws ec2 associate-address --instance-id YOUR_INSTANCE_ID --allocation-id YOUR_ALLOCATION_ID
```

test your connection with 

```bash
ssh -i NVFlareServerKeyPair.pem ubuntu@myproject-server.mydomain.edu
```

add a cronjob to ensure that the server will restart after a reboot

```bash
(crontab -l 2>/dev/null; echo "@reboot  /var/tmp/cloud/startup/start.sh >> /var/tmp/nvflare-server-start.log 2>&1") | crontab
```

Make sure the newest packages are installed:

```bash
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
sudo reboot 
```

## Installing Client

please see [Using NVFlare as an Org Admin](#using-nvflare-as-an-org-admin)
