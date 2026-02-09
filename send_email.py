import json
import boto3
import os

ses = boto3.client('ses')

def lambda_handler(event, context):
    print("Event received:", json.dumps(event))

    # Loop through every event (usually just one)
    for record in event['Records']:
        
        # We only care when an item is DELETED (Time to wake up!)
        if record['eventName'] == 'REMOVE':
            
            # Get the data that was just deleted
            old_image = record['dynamodb']['OldImage']
            message = old_image['message']['S']
            
            # Send the Email 📧
            try:
                ses.send_email(
                    Source="", # <--- UPDATE THIS
                    Destination={
                        'ToAddresses': [""] # <--- UPDATE THIS
                    },
                    Message={
                        'Subject': {'Data': "Time Capsule: A Message from the Past! ⏳"},
                        'Body': {
                            'Text': {'Data': f"You wrote this message to yourself:\n\n{message}"}
                        }
                    }
                )
                print("Email sent successfully!")
            except Exception as e:
                print(f"Error sending email: {e}")
                
    return "Done"