import json
import datetime
import os

# Friday in Calendar.current (Swift) is 6 (Sunday=1)
# 2 PM is 14 * 3600 = 50400 seconds since midnight

now = datetime.datetime.now()
# Create two past Fridays
friday1 = now - datetime.timedelta(days=7)
friday2 = now - datetime.timedelta(days=14)

events = [
    {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "date": friday1.isoformat() + "Z",
        "weekday": 6,
        "timeSinceMidnight": 50400,
        "chargeLevel": 100
    },
    {
        "id": "123e4567-e89b-12d3-a456-426614174001",
        "date": friday2.isoformat() + "Z",
        "weekday": 6,
        "timeSinceMidnight": 50400,
        "chargeLevel": 100
    }
]

app_support = os.path.expanduser("~/Library/Application Support/Glide")
os.makedirs(app_support, exist_ok=True)
with open(os.path.join(app_support, "smart_charging_events.json"), "w") as f:
    json.dump(events, f)

print("Fake data injected!")
