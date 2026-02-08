import json
import time
import os
import boto3

#connect to database
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('time-capsule')  #match the database name with the one in .tf code

def lambda_handler(event, context):
    try:
        #get the request body
        body = json.loads(event['body'])
        #get the message from the request body
        message = body['message']
        seconds = int(body.get('seconds', 0)) 
        current_time = int(time.time())
        delete_at = current_time + seconds
        table.put_item(
            Item={
                'id': str(current_time),  # Use current time as a unique ID
                'message': message,  #the actaul message
                'expiration_time': delete_at #when to destroy
            }
        )
        #return a success response
        return {
            'statusCode': 200,
            'body': json.dumps('Message stored successfully!')
        }
    except Exception as e:
        #return an error response
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error storing message: {str(e)}')
        }