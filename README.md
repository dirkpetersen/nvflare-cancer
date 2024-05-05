# NVFlare in Cancer Research 

We are setting up a project to explore federated learning using NVFlare. We assume that the participants will have one of these options available: 

- A AWS or Azure cloud account
- An on-premises Slurm HPC system with GPU 
- A Windows Laptop with a GPU installed 

The central NVFlare server including dashboard with be installed by the IT department of one of the participating institutions. The researchers in this institution will use an NVFlare compute client on their HPC system and will have no access to the central system. 

## Installing NVFlare Environment 

For consistency reasons we recommend installing the lastest NVFlare supported Python version (NVFlare 2.40 and Python 3.10 as of May 2024) from the same source. We propose the Rye Package manager by Armin Ronacher (the maker of Flask). Below are the instructions for Linux / Mac, please see Windows instructions [here](https://rye-up.com/). It will install the Rye package manager, which installs Python 3.10 in a reproducible way and make it the default Python on your system (it will edit file ~/.python-version)

```
curl -sSf https://rye-up.com/get | bash
. ~/.rye/env
rye fetch 3.10
rye pin 3.10
```

The Rye installer will put `. ~/.rye/env` into ~/.profile to ensure that this Python version is ready at the next login. If you have an older HPC system it may not use the file ~/.profile but ~/.bash_profile instead. just run `echo '. ~/.rye/env' >> ~/.bash_profile` in that case. 

A quick test should show that the default python is latest Python 3.10

```
$ python --version
Python 3.10.14
```

install NVFlare in a new virtual environment and source it

```
$ rye init ~/.local/nvf && cd ~/.local/nvf && rye add nvflare && rye sync && cd ~

success: Initialized project in /home/pytester/.local/nvf
  Run `rye sync` to get started
Initializing new virtualenv in /home/pytester/.local/nvf/.venv
Python version: cpython@3.10.14
Added nvflare>=2.4.0 as regular dependency

$ source ~/.local/nvf/.venv/bin/activate
(nvf) ~$
```

if you plan to work with your NVFlare project for a while you should consider activating it automatically each time you login, e.g. 

```
echo 'source ~/.local/nvf/.venv/bin/activate' >> ~/.profile  # or ~/.bash_profile for older Linux
```

Next we will be connecting with an NVFlare Dashboard that someone else put up 

## Connecting to NVFlare dashboard 

For the purpose of this example we assume that your collaborators have setup a central NVFlare server in AWS that will manage the project. We assume this server will be at `flareboard.mydomain.edu` (your collaborators will share the actual address with you). Once you have registered as a member and been approved you will be able to login to the dashboard and can download the eonsole 

![image](https://github.com/dirkpetersen/nvflare-cancer/assets/1427719/fd174c42-c0dc-4fe2-9525-8bfb65529a8a)



## Installing Dashboard

The NVFlare dashboard will be created in an isolated AWS account. Please see these instructions to [create the dashboard in AWS](https://nvflare.readthedocs.io/en/main/real_world_fl/cloud_deployment.html#create-dashboard-on-aws)

If you receive a VPC error such as (`VPCIdNotSpecified`) it means that no default network configuration ([Default VPC](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html)) has been created by your AWS administrator. Default VPCs are often used in smaller test envionments. You can create a default VPC by using this command: `aws ec2 create-default-vpc` . If that fails you may not have permission to create this and have to reach out to your AWS Administrator for a solution. In NVFlare versions > 2.4 you will also be able to pick your own VPC. 

### Getting dashboard production ready 

Now the dashboard is installed and you would like to use it more permanently, we need to:

1. Set up DNS/HTTPS to ensure that users don't have to connect to an ip-address insecurely.  
1. Ensure that the dashboard will be automatically started after a reboot 

#### About 1. Start at reboot 

Login to the dashboard instance via ssh (using -i NVFlareDashboardKeyPair.pem)  

```
ssh -i "NVFlareDashboardKeyPair.pem" ubuntu@ec2-xxx-xxx-xxx-xxx.us-west-2.compute.amazonaws.com
```

and run this command to add a line to the crontab file:

```
(crontab -l 2>/dev/null; echo "@reboot \$HOME/.local/bin/nvflare dashboard --start -p 443 -f \$HOME > /var/tmp/nvflare-docker-start.log 2>&1") | crontab
```


#### About 2. DNS/HTTPS

Many IT departments advise their users to only log into websites that do offer secure transport (such as https/ssl). To obtain an SSL certificate we need to configure a DNS domain name that is tied to the certificate, but before we can get a DNS entry we need to create a floating permanent IP address, (In AWS lingo this is an elastic IP address) that will be tied to the machine that runs the dashboard but can also be assinged to another machine later in case of a migration. 

```
aws ec2 allocate-address --domain vpc  # get YOUR_ALLOCATION_ID
aws ec2 describe-instances #  get YOUR_INSTANCE_ID
aws ec2 associate-address --instance-id YOUR_INSTANCE_ID --allocation-id YOUR_ALLOCATION_ID
```

then there are 2 options: In most cases you will obtain a DNS name and certificate from your IT department. For this example we assume your domain name is `flareboard.mydomain.edu`. In some cases someone else may have configured the AWS DNS Service (Route 53) that allows you to manage your own DNS. If you manage your own DNS you can also easily use SSL certs from [Let's Encrypt](https://letsencrypt.org/). 

##### DNS and SSL Certificate through your IT department 

Once your DNS entry is setup and you have received your SSL cert from IT you can setup secure transport. In most cases you will receive a pem certificate file protected by a password. Upload that file to flareboard.mydomain.edu and 

```
(nvf) $ scp -i "NVFlareDashboardKeyPair.pem" mycert.pem ubuntu@flareboard.mydomain.edu
(nvf) $ ssh -i "NVFlareDashboardKeyPair.pem" ubuntu@flareboard.mydomain.edu
```

use the openssl command to extract the x509 certificate and the key file into the ~/cert folder. Restart the container after that. On the flareboard server paste in these commands:

```
openssl rsa -in mycert.pem -out ~/cert/web.key
openssl x509 -in mycert.pem -out ~/cert/web.crt
nvflare dashboard --stop 
nvflare dashboard --start -f ~
```

##### DNS through Route53 and let's encrypt SSL 


Paste in these commands to generate the export statements, 

```
aws configure get aws_access_key_id | awk '{print "export AWS_ACCESS_KEY_ID=" $1}'
aws configure get aws_secret_access_key | awk '{print "export AWS_SECRET_ACCESS_KEY=" $1}'
aws configure get aws_session_token | awk '{print "export AWS_SESSION_TOKEN=" $1}'
```

copy these, login to the flaredshboard server 

```
ssh -i "NVFlareDashboardKeyPair.pem" ubuntu@ec2-xxx-xxx-xxx-xxx.us-west-2.compute.amazonaws.com
```

and paste them into the terminal, install the aws cli and the certbot-dns-route53 package 

```
python3 -m pip install awscli certbot-dns-route53
```

To register our IP address in the AWS DNS system called Route 53 we need to first get the ID of the hosted zone (which is a domain or sub domain in DNS, here MYHOSTEDZONEID) 

```
aws route53 list-hosted-zones
```

and then register a new hostname in this hosted zone using the aws route53 command. Replace flareboard.mydomain.edu with your fully qualified domain name and 123.123.123.123 with the elastic ip address you created earlier. 

```
JSON53="{\"Comment\":\"DNS update\",\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"flareboard.mydomain.edu\",\"Type\":\"A\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"123.123.123.123\"}]}}]}"
aws route53 change-resource-record-sets --hosted-zone-id MYHOSTEDZONEID --change-batch "${JSON53}"
```

Then we can use run certbot to connect to letsencrypt.org and create our SSL certificate and copy the files to ~/cert

```
certbot certonly --dns-route53 --register-unsafely-without-email --agree-tos --config-dir ~/cert --work-dir ~/cert --logs-dir ~/cert -d flareboard.mydomain.edu
cp ~/cert/live/flareboard.mydomain.edu/fullchain.pem ~/cert/web.crt
cp ~/cert/live/flareboard.mydomain.edu/privkey.pem ~/cert/web.key
chmod 600 ~/cert/live/flareboard.mydomain.edu/privkey.pem ~/cert/web.key
```

and restart the dashboard server 

```
nvflare dashboard --stop 
nvflare dashboard --start -f ~
```

Let's encrypt ssl certs have a reputation of high security because they expire after 90 days but can be renewed automatically. For this we simply setup a cronjob that runs monthly on the first of every month. Note it may not succeed every month as Let's encrypt does not allow renewing certs that are younger than 60 days. Run this command

```
(crontab -l 2>/dev/null; echo "0 0 1 * * \$HOME/.local/bin/certbot renew --config-dir \$HOME/cert --work-dir \$HOME/cert --logs-dir \$HOME/cert >> /var/tmp/certbot-renew.log 2>&1") | crontab
```

## Installing Server

The server is a central system that is installed alongside the dashboard by the project administrator. The users from the federated sites will connect first to the dashbard to download a configuration and then install a client to build a connection to the server to exhange ML models and meta information but not share their data.

As a project admin login to the dashboard and download the server startup kit

![image](https://github.com/dirkpetersen/nvflare-cancer/assets/1427719/523aa5a0-7c28-4713-b629-352caa90ea4c)

