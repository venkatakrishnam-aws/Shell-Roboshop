#!/bin/bash

# Variables
AMIID="ami-0220d79f3f480ecf5"
SecurityGroup="sg-0af8866461c9712e4"
InstanceType="t2.micro"
instances=("mongoDB" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")
Zone="us-east-1a"
ZoneID="Z0031597K7311GPXG9MF"
Domain="vk98.space"

for instance in "${instances[@]}"; do
    echo "🚀 Deploying $instance..."

    # Create EC2 instance
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMIID \
        --instance-type $InstanceType \
        --security-group-ids $SecurityGroup \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
        --placement AvailabilityZone=$Zone \
        --count 1 \
        --query "Instances[0].InstanceId" \
        --output text)

    echo "✅ Created EC2 instance $INSTANCE_ID for $instance"

    # Wait until instance is running
    echo "⏳ Waiting for $instance ($INSTANCE_ID) to be running..."
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID
    echo "✅ $instance is now running"

    # Get IP address
    if [ "$instance" != "frontend" ]; then
        IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query "Reservations[].Instances[].PrivateIpAddress" \
            --output text)

        if [ -n "$IP" ] && [ "$IP" != "None" ]; then
            echo "📌 Assigning Private DNS record for $instance → $IP"
            aws route53 change-resource-record-sets --hosted-zone-id $ZoneID --change-batch "{
              \"Changes\": [{
                \"Action\": \"UPSERT\",
                \"ResourceRecordSet\": {
                  \"Name\": \"$instance.$Domain.\",
                  \"Type\": \"A\",
                  \"TTL\": 60,
                  \"ResourceRecords\": [{\"Value\": \"$IP\"}]
                }
              }]
            }"
            echo "✅ Assigned Private DNS record for $instance"
        else
            echo "⚠️ Skipping DNS assignment for $instance — no Private IP found"
        fi
    else
        IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query "Reservations[].Instances[].PublicIpAddress" \
            --output text)

        if [ -n "$IP" ] && [ "$IP" != "None" ]; then
            echo "🌍 Assigning Public DNS record for frontend → $IP"
            aws route53 change-resource-record-sets --hosted-zone-id $ZoneID --change-batch "{
              \"Changes\": [{
                \"Action\": \"UPSERT\",
                \"ResourceRecordSet\": {
                  \"Name\": \"$Domain.\",
                  \"Type\": \"A\",
                  \"TTL\": 60,
                  \"ResourceRecords\": [{\"Value\": \"$IP\"}]
                }
              }]
            }"
            echo "✅ Assigned Public DNS record for frontend"
        else
            echo "⚠️ Skipping DNS assignment for frontend — no Public IP found"
        fi
    fi
done

echo "🎉 All EC2 instances deployed and DNS records assigned (where IPs were available)"
