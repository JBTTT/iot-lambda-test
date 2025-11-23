import json
import os
import boto3

sns = boto3.client("sns")

SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")

def handler(event, context):
    """
    Event is coming from AWS IoT Core rule as a JSON payload.
    Example payload:
    {
      "temperature": 45.2,
      "deviceId": "sim-device-1",
      "timestamp": 1700000000
    }
    """

    print("Received event:", json.dumps(event))

    # Simple message formatting
    subject = "cet11-grp1 IoT Alert"
    message = f"IoT Alert received from Lambda:\n\n{json.dumps(event, indent=2)}"

    if not SNS_TOPIC_ARN:
        print("SNS_TOPIC_ARN is not set. Exiting without sending message.")
        return {"statusCode": 500, "body": "SNS_TOPIC_ARN not configured"}

    try:
        resp = sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        print("SNS publish response:", resp)
        return {
            "statusCode": 200,
            "body": json.dumps({"messageId": resp.get("MessageId")})
        }
    except Exception as e:
        print("Error publishing to SNS:", str(e))
        return {"statusCode": 500, "body": "Error publishing to SNS"}
