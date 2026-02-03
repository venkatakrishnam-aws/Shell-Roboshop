#!/bin/bash

USERID=$(id -u)

# Colors
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
nocolor="\e[0m"

logs_folder="/var/log/Roboshop-logs"
script_name=$(basename "$0" | cut -d '.' -f1)
log_file="$logs_folder/$script_name.log"
scriptdir=$(pwd)

mkdir -p $logs_folder
echo -e "${green}script started at: $(date)${nocolor}" | tee -a $log_file

# Check for root user
if [ $USERID -ne 0 ]; then
   echo "You are not a root user, please switch to root access to run this script" | tee -a $log_file
   exit 1
else
   echo "You are a root user hence proceeding with the installation." | tee -a $log_file
fi

# Function to validate installation
validate_installation() {
  if [ $1 -ne 0 ]; then
      echo -e "${red}$2 failed.${nocolor}" | tee -a $log_file
      exit 1
  else
      echo -e "${green}$2 succeeded.${nocolor}" | tee -a $log_file
  fi
}

# NodeJS setup
dnf module disable nodejs -y | tee -a $log_file
validate_installation $? "Disabling nodejs module"

dnf module enable nodejs:20 -y | tee -a $log_file
validate_installation $? "Enabling nodejs 20 module"

dnf install nodejs -y | tee -a $log_file
validate_installation $? "Installing nodejs"

# App user
useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop | tee -a $log_file
validate_installation $? "Adding roboshop user" 

mkdir -p /app | tee -a $log_file
validate_installation $? "Creating /app directory"

# Catalogue service setup
curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip 
validate_installation $? "Downloading catalogue code"

cd /app
unzip /tmp/catalogue.zip
validate_installation $? "Unzipping catalogue files" 

npm install 
validate_installation $? "Installing nodejs dependencies"

cp $scriptdir/catalogue/catalogue.service /etc/systemd/system/catalogue.service
validate_installation $? "Copying catalogue systemd file"

systemctl daemon-reload
validate_installation $? "Reloading systemd daemon"

systemctl enable catalogue
validate_installation $? "Enabling catalogue service"

systemctl start catalogue
validate_installation $? "Starting catalogue service"

# MongoDB repo setup
curl -o /etc/yum.repos.d/mongo.repo https://raw.githubusercontent.com/daws-84s/roboshop-documentation/main/mongo.repo
validate_installation $? "Downloading MongoDB repo file"

dnf install mongodb-mongosh -y
validate_installation $? "Installing MongoDB Shell"

mongosh --host 3.90.232.170 </app/schema/mongo.js
validate_installation $? "Loading catalogue schema to MongoDB"

echo -e "${green}Catalogue setup completed successfully${nocolor}" | tee -a $log_file
echo -e "${green}script ended at: $(date)${nocolor}" | tee -a $log_file