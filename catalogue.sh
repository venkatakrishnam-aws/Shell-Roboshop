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

# Function to install packages
install_package() {
  PACKAGE=$1
  if ! rpm -q $PACKAGE &>/dev/null; then
      echo -e "${yellow}$PACKAGE not installed. Installing...${nocolor}" | tee -a $log_file
      dnf install -y $PACKAGE
      validate_installation $? "$PACKAGE installation"
  else
      echo -e "${green}$PACKAGE is already installed.${nocolor}" | tee -a $log_file
  fi
}

dnf module disable nodejs -y  | tee -a $log_file
validate_installation $? "Disabling nodejs module"

dnf module enable nodejs:20 -y  | tee -a $log_file
validate_installation $? "Enabling nodejs 20 module"

dnf install nodejs -y  | tee -a $log_file
validate_installation $? "Installing nodejs"

useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop | tee -a $log_file
validate_installation $? "Adding roboshop user" 

mkdir /app | tee -a $log_file
validate $? "Creating /app directory"

curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip 
validate_installation $? "Downloading catalogue code"

cd /app
unzip /tmp/catalogue.zip
validate_installation $? "unzipping the files" 

npm install 
validate $? """Installing nodejs dependencies"

cp /catalogue/systemd.service /etc/systemd/system/catalogue.service
validate_installation $? "Copying catalogue systemd file"
systemctl daemon-reload
validate_installation $? "Reloading systemd daemon"
systemctl enable catalogue
validate_installation $? "Enabling catalogue service"
systemctl start catalogue
validate_installation $? "Starting catalogue service"
echo -e "${green}script ended at: $(date)${nocolor}" | tee -a $log_file

cp $scriptdir/mongo.repo /etc/yum.repos.d/mongo.repo
validate_installation $? "Copying MongoDB repo file"

dnf install mongodb-mongosh -y
validate_installation $? "Installing MongoDB Shell"
echo -e "${green}MongoDB Shell installed successfully${nocolor}" | tee -a $log_file
mongosh --host mongodb-dev.vk98.space </catalogue/mongo.js
validate_installation $? "Loading catalogue schema to MongoDB"
echo -e "${green}Catalogue setup completed successfully${nocolor}" | tee -a $log_file



