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

# MongoDB setup
cp mongodb.repo /etc/yum.repos.d/mongodb.repo
validate_installation $? "Copying mongoDB repo"

dnf install -y mongodb-org | tee -a $log_file
validate_installation $? "Installing mongoDB server"

systemctl enable mongod | tee -a $log_file
validate_installation $? "Enabling mongoDB service"

systemctl start mongod | tee -a $log_file
validate_installation $? "Starting mongoDB service"

sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf | tee -a $log_file
validate_installation $? "Updating mongoDB config file"

systemctl restart mongod | tee -a $log_file
validate_installation $? "Restarting mongoDB service"
