#!/bin/bash

# Date: 2023-11-22
# Author: Robert A Engel
#
# Requirements:
# - bash
# - aws cli (authenticated)
# - jq
#
# Description:
#   Script to search for aws s3 buckets where the bucket name contains the first parameter passed.
#   If bucket names matching the search string are found, the script will empty and permanently delete the all buckets found.
#
# Usage:
#   ./aws_cli_empty_and_remove_s3_buckets.sh <param1>
#   <param1> - search string for bucket name

function print_usage() {
    echo "Usage:"
    echo "  ./aws_cli_empty_and_remove_s3_buckets.sh <param1>"
    echo "  <param1> - search string for bucket name"
}

# Empty and delete the AWS s3 buckets
function empty_and_delete_buckets() {
    jq -cr '.[]' <<< "$BUCKETS" | while read -r BUCKET_NAME; do
        echo "Deleting bucket $BUCKET_NAME"

        IS_BUCKET_VERSIONED=$(jq ".Status" <<< "$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME")")

        if [ "$IS_BUCKET_VERSIONED" == '"Enabled"' ]; then
            aws s3api delete-objects --bucket "$BUCKET_NAME" \
              --delete "$(aws s3api list-object-versions \
              --bucket "$BUCKET_NAME" \
              --output=json \
              --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" > /dev/null
        else
            aws s3 rm s3://"$BUCKET_NAME" --recursive
        fi

        aws s3 rb s3://"$BUCKET_NAME"

    done
}

# Check if the first parameter is passed, print usage if not
if [ -z "$1" ]; then
  echo  "Please pass to a string to search for..."
  print_usage
  exit 1
fi

# Get all buckets that contain the search string
BUCKET_NAME_CONTAINS_TARGET=$1
BUCKETS=$(aws s3api list-buckets --query "Buckets[?contains(Name, '${BUCKET_NAME_CONTAINS_TARGET}')].Name")

# Check if any buckets were found
if [ "$BUCKETS" == "[]" ]; then
    echo "No buckets found for $BUCKET_NAME_CONTAINS_TARGET"
    exit 0
fi

# Print the buckets found and ask for confirmation to empty and delete them
read -r -p "Are you sure you want to permanently delete these Buckets?? [y/N] $BUCKETS" -n 1
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo
    # Double check that the user really wants to delete the buckets
    read -r -p "Are you sure really sure?? [y/N]" -n 1
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        echo
        empty_and_delete_buckets
    else
        echo
        echo "Operation cancelled"
    fi
else
    echo
    echo "Operation cancelled"
fi

exit 0