#!/bin/bash

start=$(date +%s)
#
# do something
sleep 10
#
#
end=$(date +%s)

seconds=$(echo "$end - $start" | bc)
echo $seconds' sec'
