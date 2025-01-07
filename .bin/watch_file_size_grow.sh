#!/bin/bash  
# Watch File Size and Growth  
# Author: Marcelo Pacheco - marcelo@m2j.com.br  
# Syntax: watchfilesize filetomonitor
nm="$1"  
while true  
do  
  sz=$(stat -c %s "$nm")  
  sleep 1m  
  sz1=$(stat -c %s "$nm")  
  echo Growth: $(((sz1-sz)/1024/1024))MB/min Size: $((sz1/1024/1024/1024))GB  
  date
  sz=$sz1  
done
