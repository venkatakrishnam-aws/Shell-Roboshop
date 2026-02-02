#!/bin/bash 
AMIID="ami-09c813fb71547fc4f"
SecurityGroup="sg-0af8866461c9712e4"
InstanceType="t2.micro"
instances=("mongoDB" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")
Zone="us-east-1a"
ZoneID="Z0031597K7311GPXG9MF"
Domain="vk98.space"

for instance in "${instances[@]}"; do 
    echo "Deploying $instance..."
    # Example: aws ec2 run-instances --image-id $AMIID --instance-type $InstanceType --security-group-ids $SecurityGroup --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" --placement AvailabilityZone=$Zone

    echo "Created EC2 instance for $instance"

    if [ "$instance" != "frontend" ]; then
        IP=$(aws ec2 describe-instances \
            --filters "Name=tag:Name,Values=$instance" "Name=instance-state-name,Values=running" \
            --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)

        if [ -n "$IP" ] && [ "$IP" != "None" ]; then
            echo "Assigning Private Hosted Zone record for $instance with IP $IP"
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
            echo "Assigned Private Hosted Zone record for $instance"
        else
            echo "⚠️ Skipping DNS assignment for $instance — no IP found"
        fi
    else
        IP=$(aws ec2 describe-instances \
            --filters "Name=tag:Name,Values=$instance" "Name=instance-state-name,Values=running" \
            --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

        if [ -n "$IP" ] && [ "$IP" != "None" ]; then
            echo "Assigning Public DNS record for $instance with IP $IP"
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
            echo "Assigned Public DNS record for $instance"
        else
            echo "⚠️ Skipping DNS assignment for $instance — no IP found"
        fi
    fi
done  
echo "All instances deployed and DNS records assigned."
#!/bin/bash


