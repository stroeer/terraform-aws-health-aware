# Terraform script to deploy AHA Solution
# 1.0 - Initial version

# Variables defined below, you can overwrite them using tfvars or imput variables

data "aws_caller_identity" "current" {}

variable "default_tags" {
  type = map(string)
  default = {
  }
}

# Secondary region - provider config
locals {
  secondary_region = var.aha_secondary_region == "" ? var.aha_primary_region : var.aha_secondary_region
}

resource "null_resource" "package" {
  provisioner "local-exec" {
    command = "rm -rf dist lambda_function.zip && mkdir -p dist && cp -r  ${path.module}/../../src/* dist/ && pip3 install --only-binary=:all: --platform manylinux2014_x86_64 --implementation cp -r ${path.module}/../../src/requirements.txt -t dist"
  }

  triggers = {
    dependencies_versions = sha1(join("", [
      for f in fileset("${path.module}/../../src/", "*") : filesha1("${path.module}/../../src/${f}")
    ]))
    source_versions = sha1(join("", [
      for f in fileset("${path.module}/../../src/", "*") : filesha1("${path.module}/../../src/${f}")
    ]))
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "lambda_function.zip"
  source_dir  = "dist"
}

variable "aha_primary_region" {
  description = "Primary region where AHA solution will be deployed"
  type        = string
}

variable "aha_secondary_region" {
  description = "Secondary region where AHA solution will be deployed"
  type        = string
}


variable "dynamodbtable" {
  type    = string
  default = "AHA-DynamoDBTable"
}

variable "AWSOrganizationsEnabled" {
  type        = string
  default     = "No"
  description = "You can receive both PHD and SHD alerts if you're using AWS Organizations. \n If you are, make sure to enable Organizational Health View: \n (https://docs.aws.amazon.com/health/latest/ug/aggregate-events.html) to \n aggregate all PHD events in your AWS Organization. If not, you can still \n get SHD alerts."
  validation {
    condition = (
      var.AWSOrganizationsEnabled == "Yes" || var.AWSOrganizationsEnabled == "No"
    )
    error_message = "AWSOrganizationsEnabled variable can only accept Yes or No as values."
  }
}

variable "ManagementAccountRoleArn" {
  type        = string
  default     = ""
  description = "Arn of the IAM role in the top-level management account for collecting PHD Events. 'None' if deploying into the top-level management account."
}

variable "AWSHealthEventType" {
  type        = string
  default     = "issue | accountNotification | scheduledChange"
  description = "Select the event type that you want AHA to report on. Refer to \n https://docs.aws.amazon.com/health/latest/APIReference/API_EventType.html for more information on EventType."
  validation {
    condition = (
      var.AWSHealthEventType == "issue | accountNotification | scheduledChange" || var.AWSHealthEventType == "issue"
    )
    error_message = "AWSHealthEventType variable can only accept issue | accountNotification | scheduledChange or issue as values."
  }
}

variable "EventBusName" {
  type        = string
  default     = ""
  description = "This is to ingest alerts into AWS EventBridge. Enter the event bus name if you wish to send the alerts to the AWS EventBridge. Note: By ingesting you wish to send the alerts to the AWS EventBridge. Note: By ingesting these alerts to AWS EventBridge, you can integrate with 35 SaaS vendors such as DataDog/NewRelic/PagerDuty. If you don't prefer to use EventBridge, leave the default (None)."
}

variable "EventBusEndpoint" {
  type        = string
  default     = ""
  description = "Global Endpoint ID for Event Bus."
}

variable "Regions" {
  type        = string
  default     = "all regions"
  description = "By default, AHA reports events affecting all AWS regions. \n If you want to report on certain regions you can enter up to 10 in a comma separated format. \n Available Regions: us-east-1,us-east-2,us-west-1,us-west-2,af-south-1,ap-east-1,ap-south-1,ap-northeast-3, \n ap-northeast-2,ap-southeast-1,ap-southeast-2,ap-northeast-1,ca-central-1,eu-central-1,eu-west-1,eu-west-2, \n eu-south-1,eu-south-3,eu-north-1,me-south-1,sa-east-1,global"
}

variable "EventSearchBack" {
  type        = number
  default     = "1"
  description = "How far back to search for events in hours. Default is 1 hour"
}

variable "configuration" {
  description = "Allows to configure slack web hook url per account(s) so you can separate events from different accounts to different channels. Useful in context of AWS organization"
  type = list(object({
    accounts       = list(string)
    slack_hook_url = string
  }))
  default = null
}

variable "default_channel" {
  description = "Default slack channel to send events to"
  type        = string
  default     = ""
}


variable "ssm_lambda_layer_primary" {
  description = "SSM parameter name for lambda layer arn in primary region"
  type        = string
}

variable "ssm_lambda_layer_secondary" {
  description = "SSM parameter name for lambda layer arn in secondary region"
  type        = string
  default     = ""
}
