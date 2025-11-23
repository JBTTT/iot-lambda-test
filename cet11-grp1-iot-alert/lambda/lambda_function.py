import json
import os
import boto3
from decimal import Decimal

sns = boto3.client("sns")

ALERT_TOPIC_ARN = os.environ.get("ALERT_TOPIC_ARN")
MIN_TEMP = float(os.environ.get("MIN_TEMP", "25"))
MAX_TEMP = float(os.environ.get("MAX_TEMP", "40"))


def _to_float(v):
    if isinstance(v, Decimal):
        return float(v)
    try:
        return float(v)
    except Exception:
        return None


def lambda_handler(event, context):
    """
    Expected IoT payload (from MQTT) is JSON:
      { "deviceId": "sensor-1", "temperature": 42.5 }

    The IoT Topic Rule forwards the full message as 'event'.
    """
    print("Received event:", json.dumps(event))

    # event might already be a dict with temperature, or nested
    temperature = None
    device_id = event.get("deviceId") or event.get("device_id") or "unknown-device"

    if "temperature" in event:
        temperature = _to_float(event["temperature"])
    elif "payload" in event:
        # sometimes payload can be a JSON string
        try:
            payload = json.loads(event["payload"])
            temperature = _to_float(payload.get("temperature"))
            device_id = payload.get("deviceId", device_id)
        except Exception:
            pass

    if temperature is None:
        print("No temperature found in event; nothing to do.")
        return {"status": "no-temperature"}

    print(f"Device {device_id} temperature: {temperature}")

    if temperature < MIN_TEMP or temperature > MAX_TEMP:
        subject = f"IoT ALERT: {device_id} temp {temperature:.2f}°C out of range"
        message = (
            f"Device ID: {device_id}\n"
            f"Temperature: {temperature:.2f} °C\n"
            f"Expected range: {MIN_TEMP} – {MAX_TEMP} °C\n"
            f"Environment: {os.getenv('AWS_LAMBDA_FUNCTION_NAME')}"
        )

        resp = sns.publish(
            TopicArn=ALERT_TOPIC_ARN,
            Subject=subject[:100],  # SNS subject limit
            Message=message,
        )
        print("SNS publish response:", resp)

        return {"status": "alert-sent", "temperature": temperature}

    else:
        print("Temperature within normal range; no alert.")
        return {"status": "ok", "temperature": temperature}
