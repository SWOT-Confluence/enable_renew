"""AWS Lambda that renews S3 credentials from PO.DAAC.

Retrieves S3 credentials from S3 endpoint and stores them in AWS SSM Parameter
Store.
"""

# Standard imports
import sys

# Third-party imports
import boto3
import botocore

def handler(event, context):
    """Enable EventBridge schedule that invokes renew Lambda.
    
    Schedule runs every 50 minutes as creds expire every 1 hour.
    """
    
    scheduler = boto3.client("scheduler")
    try:
        # Get schedule
        get_response = scheduler.get_schedule(Name="confluence-dev1-renew")
        
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
