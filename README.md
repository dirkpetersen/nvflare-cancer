# NVFlare in Cancer Research 

We are setting up a project to explore federated learning using NVFlare. We assume that the participants will have one of these options available: 

- A AWS or Azure cloud account
- An on-premises Slurm HPC system with GPU 
- A Windows Laptop with a GPU installed 

The central NVFlare server including dashboard with be installed by the IT department of one of the participating institutions. The researchers in this institution will use an NVFlare compute client on their HPC system and will have no access to the central system. 

For consistency reasons we recommend installing the lastest NVFlare supported Python version (3.10 as of May 2024) from the same source. We propose the Rye Package manager by Armin Ronacher (the maker of Flask). Below are the instructions for Linux / Mac, please see Windows instructions [here](https://rye-up.com/). It will install the Rye package manager, which installs Python 3.10 and make it the default Python on your system (it will edit file ~/.python-version)

## Installing Environment 

```
curl -sSf https://rye-up.com/get | bash
. ~/.rye/env
rye toolchain fetch 3.10
rye pin 3.10
```

The Rye installer will put `. ~/.rye/env` into ~/.profile to ensure that the environment is ready at the next login. If you have an older HPC system it may not use the file ~/.profile but ~/.bash_profile instead. just run `echo '. ~/.rye/env' >> ~/.bash_profile` in that case. 

A quick test should show that the default python is latest Python 3.10

```
$ python --version
Python 3.10.14
```

install NVFlare in a virtual environment created by `uv` 

```
$ uv venv ~/.local/nvf
Using Python 3.10.14 interpreter at: .rye/py/cpython@3.10.14/bin/python3
Creating virtualenv at: .local/nvf
Activate with: source .local/nvf/bin/activate

$ source ~/.local/nvf/bin/activate
(nvf) $ uv pip install nvflare
```

if you plan to work with your NVFlare project for a while you should consider activating it automatically each time you login, e.g. 

```
echo 'source ~/.local/nvf/bin/activate' >> ~/.profile  # or ~/.bash_profile for older Linux
```

## Installing Dashboard

The NVFlare dashboard will be created in an isolated AWS account. Please see these instructions to [create the dashboard in AWS](https://nvflare.readthedocs.io/en/main/real_world_fl/cloud_deployment.html#create-dashboard-on-aws)

If you receive a VPC error such as (`VPCIdNotSpecified`) it means that no default network configuration ([Default VPC](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html)) has been created by your AWS administrator. Default VPCs are often used in smaller test envionments. You can create a default VPC by using this command: `aws ec2 create-default-vpc` . If that fails you may not have permission to create this and have to reach out to your AWS Administrator for a solution. In NVFlare versions > 2.4 you will also be able to pick your own VPC. 

### Getting dashboard production ready 

Now the dashboard is installed and you would like to use it more permanently, we need to:

1. Set up DNS/HTTPS to ensure that users don't have to connect to an ip-address insecurely. Transport / SSL 
1. Ensure that the dashboard will survive a reboot 


#### About 1. DNS/HTTPS

Many IT departments advise their users to never log into websites that do not offer secure transport (such as https/ssl). To obtain an SSL certificate we need to configure a DNS domain name that is tied to the certificate. Yu can configure DNS through AWS Rotue 53 but it many cases you will get the DNS as well as a certificate from your IT department. To request a DNS name you need to make sure that your ip address does not change after a reboot. To accomplish that we will setup an elastic IP address that will be tried to the machine that runs the dashboard:

```
aws ec2 allocate-address --domain vpc  # get YOUR_ALLOCATION_ID
aws ec2 describe-instances #  get YOUR_INSTANCE_ID
aws ec2 associate-address --instance-id YOUR_INSTANCE_ID --allocation-id YOUR_ALLOCATION_ID
```
Once your DNS entry is setup and you have received your SSL cert you can setup secure transport. In most cases you will receive a pem certificate file protected by a password. upload that file to the dashboard server and use the openssl command to extract x509 certificate and the key file into the ~/cert folder. Restart the container after that 

```
scp -i "NVFlareDashboardKeyPair.pem" mycert.pem ubuntu@ec2-xxx-xxx-xxx-xxx.us-west-2.compute.amazonaws.com
ssh -i "NVFlareDashboardKeyPair.pem" ubuntu@ec2-xxx-xxx-xxx-xxx.us-west-2.compute.amazonaws.com
openssl rsa -in mycert.pem -out ~/cert/web.key
openssl x509 -in mycert.pem -out ~/cert/web.crt
nvflare dashboard --stop 
nvflare dashboard --start -p 443 -f ~
```

#### About 2. Start at reboot 

Login to the dashboard instance via ssh (using -i NVFlareDashboardKeyPair.pem) and run this command to add a line to the crontab file: 

```
(crontab -l 2>/dev/null; echo "@reboot \$HOME/.local/bin/nvflare dashboard --start -p 443 -f \$HOME > /var/tmp/nvflare-docker-start.log 2>&1") | crontab
```

