#!/bin/bash
# Uses a succesful_tests.json file (created separately) to merge all Windows Event Logs for each test using jq

jq -s -r '.[].FilePath' successful_tests.json | while read -r path; do
  # Remove leading './' from the path and replace '/' with '_'
  filename=$(echo "${path#./}" | tr '/' '_')

  # Find JSON files, combine them with jq and write to a file in the directory
  find "$path" -name "WIN*.json" -exec jq -c '.[]' {} + > "${path}logs_${filename}.json"
done
