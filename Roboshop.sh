#!/bin/bash 

AMIID="ami-09c813fb71547fc4f"
SecurityGroup="sg-0af8866461c9712e4"
InstanceType="t2.micro"
instances=("mongoDB" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend"); 
Zone="us-east-1a"
ZoneID="Z0031597K7311GPXG9MF"
Domain="vk98.space"

for instance in "${instances[@]}"; do
  echo "Creating EC2 instance for $instance"
  aws ec2 run-instances --image-id $AMIID --count 1 --instance-type $InstanceType --security-group-ids $SecurityGroup --placement "AvailabilityZone=$Zone" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" 
          --query 'reservations[0].instances[0].private-ip-address' --output text

    echo "Created EC2 instance for $instance"

    if [ "$instance" != "frontend" ]; then
        IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$instance" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)
        echo "Assigning Private Hosted Zone record for $instance with IP $IP"
        aws route53 change-resource-record-sets --hosted-zone-id $ZoneID --change-request "Changes=[{Action=UPSERT,ResourceRecordSet={Name=$instance.$Domain.,Type=A,ResourceRecords=[{Value=$IP}]}}]"
        echo "Assigned Private Hosted Zone record for $instance"
    else
        IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$instance" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
        echo "Assigning Public DNS record for $instance with IP $IP"
        aws route53 change-resource-record-sets --hosted-zone-id $ZoneID --change-request "Changes=[{Action=UPSERT,ResourceRecord
    fi
done
echo "All EC2 instances created and DNS records assigned."

# Note: Ensure that AWS CLI is configured with appropriate permissions before running this script.