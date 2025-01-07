#!/bin/bash
# set the file name and desired size
file="$1"
desired_size=11000000000000 # 10 TB
# initialize variables
prev_size=$(stat -c %s "$file")
total_increase=0
speed_history=()
time_left="N/A"
while true; do
  # get current file size and calculate increase since last check
  curr_size=$(stat -c %s "$file")
  increase=$((curr_size - prev_size))
  
  # calculate average speed based on last 10 minutes
  speed_history+=($increase)
  if (( ${#speed_history[@]} > 10 )); then
    unset 'speed_history[0]'
    speed_sum=0
    for i in "${speed_history[@]}"; do
      ((speed_sum+=i))
    done
    avg_speed=$((speed_sum / ${#speed_history[@]}))
    
    # calculate estimated time to reach desired size based on average speed
    if (( avg_speed > 0 )); then
      time_left=$(((desired_size-curr_size)/avg_speed))
      time_left=$(echo $((time_left*60)) | awk '{printf "%d:%02d:%02d:%02d\n",($1/86400),($1/3600%24),($1/60%60),($1%60)}')
    fi
    
  fi
  
  # update variables for next iteration
  prev_size=$curr_size
  total_increase=$((total_increase + increase))
  
  # print results to console
  echo "Current file size: $((curr_size/1024/1024/1024)) GBytes"
  echo "Increase in last minute: $((increase/1024/1024)) MBytes"
  echo "Average speed of growth (last 10 minutes): $((avg_speed/1024/1024)) MBytes/min"
  
  if [[ "$time_left" != "N/A" ]]; then 
    echo "Estimated time to reach $((desired_size/1024/1024/1024/1024)) TBytes: $time_left"
   fi
  
   # wait for one minute before checking again 
   sleep 60
  
done
