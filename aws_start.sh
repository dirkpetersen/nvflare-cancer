#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

function report_status() {
  status="$1"
  if [ "${status}" -ne 0 ]; then
    echo "$2 failed"
    exit "${status}"
  fi
}

function check_binary() {
  echo -n "Checking if $1 exists. => "
  if ! command -v $1 &> /dev/null; then
    echo "not found. $2"
    exit 1
  else
    echo "found"
  fi
}

function prompt() {
  local __default="$1"
  read -p "$2" ans
  if [[ ! -z "$ans" ]]; then
    eval $__default="'$ans'"
  fi
}

function get_resources_file() {
  local rfile="${DIR}/../local/resources.json"  
  if [ -f "${rfile}" ]; then
    echo "${rfile}"
  elif [ -f "${rfile}.default" ]; then
    echo "${rfile}.default"
  else
    echo ""
    exit 1
  fi
}

function find_ec2_gpu_instance_type() {
  local gpucnt=0
  local gpumem=0
  if rfile=$(get_resources_file); then
    # Parse the number of GPUs and memory per GPU from the resource_manager component in local/resources.json
    gpucnt=$(jq -r '.components[] | select(.id == "resource_manager") | .args.num_of_gpus' "${rfile}")
    if [ ${gpucnt} -gt 0 ]; then
      gpumem=$(jq -r '.components[] | select(.id == "resource_manager") | .args.mem_per_gpu_in_GiB' "${rfile}")
      if [ ${gpumem} -gt 0 ]; then
        gpumem=$(( ${gpumem}*1024 ))
        printf "    finding smallest instance type with ${gpucnt} GPUs and ${gpumem} MiB VRAM ... "
        gpu_types=$(aws ec2 describe-instance-types --region ${REGION} --query 'InstanceTypes[?GpuInfo.Gpus[?Manufacturer==`NVIDIA`]].{InstanceType: InstanceType, GPU: GpuInfo.Gpus[*].{Name: Name, GpuMemoryMiB: MemoryInfo.SizeInMiB, GpuCount: Count}, Architecture: ProcessorInfo.SupportedArchitectures, VCpuCount: VCpuInfo.DefaultVCpus, MemoryMiB: MemoryInfo.SizeInMiB}' --output json)
        filtered_gpu_types=$(echo ${gpu_types} | jq "[.[] | select(.GPU | any(.GpuCount == ${gpucnt} and .GpuMemoryMiB >= ${gpumem})) | select(.Architecture | index(\"${ARCH}\"))]")
        smallest_gpu_type=$(echo ${filtered_gpu_types} | jq -r 'min_by(.VCpuCount).InstanceType')
        if [ ${smallest_gpu_type} = null ]; then
          echo "failed finding a GPU instance, EC2_TYPE unchanged."
        else
          echo "${smallest_gpu_type} found"
          EC2_TYPE=${smallest_gpu_type}
        fi
      fi
    fi
  fi
}

# parse arguments
while [[ $# -gt 0 ]]
do
  key="$1"
  case $key in
    --config)
      config_file=$2
      shift
    ;;
    --image)
      image_name=$2
      shift
    ;;
    --vpc-id)
      vpc_id=$2
      shift
    ;;
    --subnet-id)
      subnet_id=$2
      shift
    ;;
  esac
  shift
done
VM_NAME=nvflare_client
SECURITY_GROUP=nvflare_client_sg_$RANDOM
KEY_PAIR=NVFlareClientKeyPair
KEY_FILE=$(pwd)/${KEY_PAIR}.pem
AMI_IMAGE_OWNER="099720109477" # Owner account id=Amazon
AMI_NAME="ubuntu-*-22.04-amd64-pro-server"
AMI_ARCH=x86_64
EC2_TYPE_ARM=t4g.small

AMI_IMAGE=ami-01ed44191042f130f  # 22.04  20.04:ami-063da375c17d500ab 24.04:ami-0833a2b4abf788b34  (us-west-2 only)
EC2_TYPE=t2.small
TMPDIR="${TMPDIR:-/tmp}"
LOGFILE=$(mktemp "${TMPDIR}/nvflare-aws-XXX")


echo "This script requires aws (AWS CLI), sshpass, dig and jq.  Now checking if they are installed."

check_binary aws "Please see https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html on how to install it on your system."
check_binary sshpass "Please install it first."
check_binary dig "Please install it first."
check_binary jq "Please install it first."
echo "Note: run this command first for a different AWS profile:"
echo "  export AWS_PROFILE=your-profile-name."

if [ -z ${vpc_id+x} ]; then
    using_default_vpc=true
else
    using_default_vpc=false
fi

if [ -z ${image_name+x} ]; then
    container=false
else
    container=true
fi

if [ $container = true ]; then
  AMI_IMAGE=ami-06b8d5099f3a8d79d
  EC2_TYPE=t2.xlarge
fi

echo -e "\nChecking AWS identity ... \n"
aws_identity=$(aws sts get-caller-identity)
if [[ $? -ne 0 ]]; then
  echo ""
  exit 1
fi

REGION=$(aws configure get region 2>/dev/null)
: "${REGION:=us-west-2}"
: "${AWS_DEFAULT_REGION:=$REGION}"
: "${AWS_REGION:=$AWS_DEFAULT_REGION}"
REGION=${AWS_REGION}

if [ -z ${config_file+x} ]; then 
    useDefault=true
else
    useDefault=false
    . $config_file
    report_status "$?" "Loading config file"
fi

if [ $useDefault = true ]; then 
  while true; do
    read -e -i ${REGION} -p "* Cloud EC2 region, press ENTER to accept default: " REGION 
    if [ ${container} = false ]; then
      read -e -i ${AMI_NAME} -p "* Cloud AMI image name, press ENTER to accept default (use amd64 or arm64): " AMI_NAME
      printf "    retrieving AMI ID for ${AMI_NAME} ... " 
      IMAGES=$(aws ec2 describe-images --region ${REGION} --owners ${AMI_IMAGE_OWNER} --filters "Name=name,Values=*${AMI_NAME}*" --output json)
      if [ "${#IMAGES}" -lt 30 ]; then
        echo -e "\nNo images found, starting over\n"
        continue
      fi
      AMI_IMAGE=$(echo $IMAGES | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId')
      echo "${AMI_IMAGE} found"

      if [[ "$AMI_NAME" == *"arm64"* ]]; then
        ARCH="arm64"
        EC2_TYPE=${EC2_TYPE_ARM}
      fi
      find_ec2_gpu_instance_type
    fi
    read -e -i ${EC2_TYPE} -p "* Cloud EC2 type, press ENTER to accept default: " EC2_TYPE
    read -e -i ${AMI_IMAGE} -p "* Cloud AMI image id, press ENTER to accept default: " AMI_IMAGE
    prompt ans "region = ${REGION}, EC2 type = ${EC2_TYPE}, ami image = ${AMI_IMAGE} , OK? (Y/n) "
    if [[ $ans = "" ]] || [[ $ans =~ ^(y|Y)$ ]]; then
      break
    fi
  done
fi

if [ $container = false ]; then
  echo "If the client requires additional Python packages, please add them to: "
  echo "    ${DIR}/requirements.txt"
  prompt ans "Press ENTER when it's done or no additional dependencies. "
  echo ""
fi

# Check if default VPC exists
if [ $using_default_vpc == true ]; then 
  echo "Checking if default VPC exists"
  found_default_vpc=$(aws ec2 describe-vpcs --region ${REGION} | jq '.Vpcs[] | select(.IsDefault == true)')
  if [ -z "${found_default_vpc}" ]; then
    echo "No default VPC found.  Please create one before running this script with the following command."
    echo "aws ec2 create-default-vpc --region ${REGION}"
    echo "or specify your own vpc and subnet with --vpc-id and --subnet-id"
    exit
  else
    echo "Default VPC found"
  fi
else
  echo "Please check the vpc-id $vpc_id and subnet-id $subnet_id are correct and they support EC2 with public IP and internet gateway with proper routing."
  echo "This script will use the above info to create EC2 instance."
fi

cd $DIR/..
# Generate key pair

echo "Generating key pair for VM"

aws ec2 delete-key-pair --region ${REGION} --key-name $KEY_PAIR > /dev/null 2>&1
rm -rf $KEY_FILE
aws ec2 create-key-pair --region ${REGION} --key-name $KEY_PAIR --query 'KeyMaterial' --output text > $KEY_FILE
report_status "$?" "creating key pair"
chmod 400 $KEY_FILE

# Generate Security Group
# Try not reusing existing security group because we have to modify it for our own need.
if [ $using_default_vpc == true ]; then
  sg_id=$(aws ec2 create-security-group --region ${REGION} --group-name $SECURITY_GROUP --description "NVFlare security group" | jq -r .GroupId)
else
  sg_id=$(aws ec2 create-security-group --region ${REGION} --group-name $SECURITY_GROUP --description "NVFlare security group" --vpc-id $vpc_id | jq -r .GroupId)
fi
report_status "$?" "creating security group"
my_public_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
if [ "$?" -eq 0 ] && [[ "$my_public_ip" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
  aws ec2 authorize-security-group-ingress --region ${REGION} --group-id $sg_id --protocol tcp --port 22 --cidr ${my_public_ip}/32 > ${LOGFILE}.sec_grp.log
else
  echo "getting my public IP failed, please manually configure the inbound rule to limit SSH access"
  aws ec2 authorize-security-group-ingress --region ${REGION} --group-id $sg_id --protocol tcp --port 22 --cidr 0.0.0.0/0 > ${LOGFILE}.sec_grp.log
fi
report_status "$?" "creating security group rules"

# Start provisioning

echo "Creating VM at region ${REGION}, this may take a few minutes ... "

ami_info=$(aws ec2 describe-images --region ${REGION} --image-ids ${AMI_IMAGE} --output json)
amidevice=$(echo ${ami_info} | jq -r '.Images[0].BlockDeviceMappings[0].DeviceName')
block_device_mappings=$(echo ${ami_info} | jq -r '.Images[0].BlockDeviceMappings')
original_size=$(echo ${block_device_mappings} | jq -r '.[0].Ebs.VolumeSize')
original_volume_type=$(echo ${block_device_mappings} | jq -r '.[0].Ebs.VolumeType')
new_size=$((original_size + 8))
bdmap='[{"DeviceName":"'${amidevice}'","Ebs":{"VolumeSize":'${new_size}',"VolumeType":"'${original_volume_type}'","DeleteOnTermination":true}}]'

if [ ${using_default_vpc} == true ]; then
  aws ec2 run-instances --region ${REGION} --image-id ${AMI_IMAGE} --count 1 --instance-type ${EC2_TYPE} --key-name ${KEY_PAIR} --security-group-ids ${sg_id} --block-device-mappings ${bdmap} > vm_create.json
else
  aws ec2 run-instances --region ${REGION} --image-id ${AMI_IMAGE} --count 1 --instance-type ${EC2_TYPE} --key-name ${KEY_PAIR} --security-group-ids ${sg_id} --block-device-mappings ${bdmap} --subnet-id ${subnet_id} > vm_create.json
fi
report_status "$?" "creating VM"
instance_id=$(jq -r .Instances[0].InstanceId vm_create.json)
KEY_FILE2=$(pwd)/${KEY_PAIR}_${instance_id}.pem
cp -f ${KEY_FILE} ${KEY_FILE2}
chmod 400 ${KEY_FILE2}

aws ec2 wait instance-status-ok --region ${REGION} --instance-ids "${instance_id}"
aws ec2 describe-instances --region ${REGION} --instance-ids "${instance_id}" > vm_result.json

IP_ADDRESS=$(jq -r .Reservations[0].Instances[0].PublicIpAddress vm_result.json)

echo "VM created with IP address: ${IP_ADDRESS}"

echo "Copying files to ${VM_NAME}"
DEST_SITE=ubuntu@${IP_ADDRESS}
DEST=${DEST_SITE}:/var/tmp/cloud
echo "Destination folder is ${DEST}"
scp -q -i ${KEY_FILE2} -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $PWD $DEST
report_status "$?" "copying startup kits to VM"

rm -f ${LOGFILE}.log
if [ $container = true ]; then
  echo "Launching container with docker option ${DOCKER_OPTION}."
  ssh -f -i ${KEY_FILE2} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${DEST_SITE} \
  "docker run -d -v /var/tmp/cloud:/var/tmp/cloud --network host ${DOCKER_OPTION} ${image_name} \
  /bin/bash -c \"python -u -m nvflare.private.fed.app.client.client_train -m /var/tmp/cloud \
  -s fed_client.json --set uid=AWS-T4 secure_train=true config_folder=config org=Test \" " > ${LOGFILE}.log 2>&1 
  report_status "$?" "launching container"
else
  # Spawn a process to install os packages as root
  echo "Installing os packages as root in $VM_NAME, may take a few minutes ... "
  ssh -f -i ${KEY_FILE2} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${DEST_SITE} \
  ' NVIDIA_OS_PKG="nvidia-driver-550-server" && sudo apt update && \
  sudo DEBIAN_FRONTEND=noninteractive apt install -y python3-dev gcc && \
  . /etc/os-release && if [ "${VERSION_ID}" \< "22.04" ]; then NVIDIA_OS_PKG="nvidia-driver-535-server"; fi && \
  if lspci | grep -i nvidia; then sudo DEBIAN_FRONTEND=noninteractive apt install -y ${NVIDIA_OS_PKG}; fi && \
  if lspci | grep -i nvidia; then sudo modprobe nvidia; fi && sleep 10 && \
  exit' >> ${LOGFILE}.log 2>&1
  report_status "$?" "installing os packages"
  sleep 10
  # Spawn a process to install packages as user
  echo "Installing user space packages in $VM_NAME, may take a few minutes ... "
  ssh -f -i ${KEY_FILE2} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${DEST_SITE} \
  ' echo "export PATH=~/.local/bin:$PATH" >> ~/.bashrc && \
  export PATH=/home/ubuntu/.local/bin:$PATH && \
  pwd && wget -q https://bootstrap.pypa.io/get-pip.py && \
  timeout 300 sh -c """until [ -f /usr/bin/gcc ]; do sleep 3; done""" && \
  python3 get-pip.py --break-system-packages && python3 -m pip install --break-system-packages nvflare && \
  touch /var/tmp/cloud/startup/requirements.txt && \
  printf "installing from requirements.txt: " && \
  cat /var/tmp/cloud/startup/requirements.txt | tr "\n" " " && \
  python3 -m pip install --break-system-packages --no-cache-dir -r /var/tmp/cloud/startup/requirements.txt && \
  (crontab -l 2>/dev/null; echo "@reboot  /var/tmp/cloud/startup/start.sh >> /var/tmp/nvflare-start.log 2>&1") | crontab && \
  NVIDIAMOD="nvidia.ko.zst" && . /etc/os-release && if [ "${VERSION_ID}" \< "24.04" -a "${VERSION_ID}" \> "16.04" ]; then NVIDIAMOD="nvidia.ko"; fi && \
  if lspci | grep -i nvidia; then timeout 900 sh -c """until [ -f /lib/modules/$(uname -r)/updates/dkms/${NVIDIAMOD} ]; do sleep 3; done"""; fi && \
  sleep 60 && nohup /var/tmp/cloud/startup/start.sh && sleep 20 && \
  exit' >> ${LOGFILE}.log 2>&1
  report_status "$?" "installing user space packages"
  sleep 10
fi
echo "System was provisioned, packages may continue to install in the background."
echo "To terminate the EC2 instance, run the following command:"
echo "  aws ec2 terminate-instances --region ${REGION} --instance-ids ${instance_id}"
echo "Other resources provisioned"
echo "security group: ${SECURITY_GROUP}"
echo "key pair: ${KEY_PAIR}"
echo "review install progress:"
echo "  tail -f ${LOGFILE}.log"
echo "login to instance:"
echo "  ssh -i ${KEY_FILE2} ubuntu@${IP_ADDRESS}"
