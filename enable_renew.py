"""AWS Lambda that renews S3 credentials from PO.DAAC.

Retrieves S3 credentials from S3 endpoint and stores them in AWS SSM Parameter
Store.
"""

# Standard imports
import json
import os
import pathlib
import sys

# Third-party imports
import boto3
import botocore

# Constants
EFS_DIR = pathlib.Path("/mnt/data")

def handler(event, context):
    """Enable EventBridge schedule that invokes renew Lambda. Lambda also
    creates a fresh continent.json file for next Confluence workflow execution.
    
    Schedule runs every 50 minutes as creds expire every 1 hour.
    """
    
    # Enable schedule
    scheduler = boto3.client("scheduler")
    try:
        # Get schedule
        get_response = scheduler.get_schedule(Name=f"{os.getenv('ENV_PREFIX')}-renew")
        
        # Update schedule
        update_response = scheduler.update_schedule(
            Name=get_response["Name"],
            GroupName=get_response["GroupName"],
            FlexibleTimeWindow=get_response["FlexibleTimeWindow"],
            ScheduleExpression=get_response["ScheduleExpression"],
            Target=get_response["Target"],
            State="ENABLED"
        )
        print("Enabled EventBridge schedule for renew lambda function.")      
    except botocore.exceptions.ClientError as e:
        print(f"Error encountered - {e}")
        sys.exit(1)
        
    # Get continent.json from S3 to EFS
    download_continent_json()
    print(f"Downloaded: {EFS_DIR.joinpath('continent-datagen.json')}")
    
    # Send success response
    sf = boto3.client("stepfunctions")
    try:
        response = sf.send_task_success(
            taskToken=event["token"],
            output="{}"
        )
        print("Sent task success.")
    
    except botocore.exceptions.ClientError as err:
        response = sf.send_task_failure(
            taskToken=event["token"],
            error=err.response['Error']['Code'],
            cause=err.response['Error']['Message']
        )
        print("Sent task failure.")
        
def download_continent_json():
    """Download continent JSON from S3 bucket to EFS."""
    
    # Download
    s3 = boto3.client("s3")
    s3.download_file(f"{os.getenv('ENV_PREFIX')}-json", 
                     "continent-datagen.json", 
                     EFS_DIR.joinpath("continent-datagen.json")
                     )
