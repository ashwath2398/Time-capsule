terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

#creation of dynamodb table to store the time capsule data
resource "aws_dynamodb_table" "time_capsule" {
  name         = "time-capsule"
  billing_mode = "PAY_PER_REQUEST"
    hash_key     = "id" #primary key

    attribute {
        name = "id"
        type = "S" #string type
    }
    ttl {
      attribute_name = "expiration_time"  #check this column
      enabled = true
    }
    stream_enabled = true
    stream_view_type = "OLD_IMAGE" #view exactly the old image of the item before it gets deleted
}


#creating iam user for dynamodb to assume role
resource "aws_iam_role" "time_capsule_role" {
  name = "time-capsule-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

#iam policy to define the permissions (custom)
resource "aws_iam_policy" "time_capsule_policy" {
  name        = "time-capsule-policy"
  

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow" #allow to put and get item from the table
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",

        ]
        Resource = "aws_dynamodb_table.time_capsule.arn"
      },
      {
        #allow effect to stream
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
        ]
      },
      #global powers to log and send email
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ses:SendEmail",
          
        ]
        Resource = "*"
      }
    ]
  })
}

#attach the policy to the role
resource "aws_iam_role_policy_attachment" "time_capsule_role_attachment" {
  role       = aws_iam_role.time_capsule_role.name
  policy_arn = aws_iam_policy.time_capsule_policy.arn
}