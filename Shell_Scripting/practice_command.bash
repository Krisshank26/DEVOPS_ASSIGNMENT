#!/bin/bash

date=$(date ) 
hostname=$(hostname ) 
whoami=$(whoami ) 
du=$(df -h ) 

echo "Date is: $date" 

echo "Hostname is: $hostname " 

echo "Username is: $whoami " 

echo "Disk Usage is: $du " 

read -p "Enter your name please: " name 

echo "Name is: $name " 

mkdir folder 

cd folder 

touch file.txt 

ps aux > file.txt 