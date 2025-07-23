# DynamoDB table - Create if secondary region not set
resource "aws_dynamodb_table" "AHA-DynamoDBTable" {
  count                       = var.aha_secondary_region == "" ? 1 : 0
  billing_mode                = "PROVISIONED"
  hash_key                    = "arn"
  name                        = var.dynamodbtable
  read_capacity               = 5
  write_capacity              = 5
  stream_enabled              = false
  deletion_protection_enabled = true

  server_side_encryption {
    enabled = true
  }

  attribute {
    name = "arn"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  timeouts {}

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

# DynamoDB table - Multi region Global Table - Create if secondary region is set
#tfsec:ignore:aws-dynamodb-enable-at-rest-encryption
resource "aws_dynamodb_table" "AHA-GlobalDynamoDBTable" {
  count                       = var.aha_secondary_region == "" ? 0 : 1
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "arn"
  name                        = var.dynamodbtable
  stream_enabled              = true
  stream_view_type            = "NEW_AND_OLD_IMAGES"
  deletion_protection_enabled = true

  tags = {
    Name = var.dynamodbtable
  }

  attribute {
    name = "arn"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  replica {
    region_name            = var.aha_secondary_region
    point_in_time_recovery = true
    propagate_tags         = true
  }

  timeouts {}

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}
# Tags for DynamoDB - secondary region
resource "aws_dynamodb_tag" "AHA-GlobalDynamoDBTable" {
  count        = var.aha_secondary_region == "" ? 0 : 1
  provider     = aws.secondary_region
  resource_arn = replace(aws_dynamodb_table.AHA-GlobalDynamoDBTable[count.index].arn, var.aha_primary_region, var.aha_secondary_region)
  key          = "Name"
  value        = var.dynamodbtable
}
# Tags for DynamoDB - secondary region - default_tags
resource "aws_dynamodb_tag" "AHA-GlobalDynamoDBTable-Additional-tags" {
  for_each     = { for key, value in var.default_tags : key => value if var.aha_secondary_region != "" }
  provider     = aws.secondary_region
  resource_arn = replace(aws_dynamodb_table.AHA-GlobalDynamoDBTable[0].arn, var.aha_primary_region, var.aha_secondary_region)
  key          = each.key
  value        = each.value
}

# aws_lambda_function - AHA-LambdaFunction - Primary region
resource "aws_lambda_function" "AHA-LambdaFunction-PrimaryRegion" {
  description      = "Lambda function that runs AHA"
  function_name    = "AHA-LambdaFunction"
  handler          = "handler.main"
  memory_size      = 128
  timeout          = 600
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  #    s3_bucket                      = var.S3Bucket
  #    s3_key                         = var.S3Key
  reserved_concurrent_executions = -1
  role                           = aws_iam_role.AHA-LambdaExecutionRole.arn
  runtime                        = "python3.13"

  environment {
    variables = {
      "DYNAMODB_TABLE"                       = var.dynamodbtable
      "EVENT_SEARCH_BACK"                    = var.EventSearchBack
      "HEALTH_EVENT_TYPE"                    = var.AWSHealthEventType
      "ORG_STATUS"                           = var.AWSOrganizationsEnabled
      "REGIONS"                              = var.Regions
      "MANAGEMENT_ROLE_ARN"                  = var.ManagementAccountRoleArn
      "EVENT_BUS_NAME"                       = var.EventBusName
      "EVENT_BUS_ENDPOINT"                   = var.EventBusEndpoint
      "MANAGEMENT_ACCOUNT_ROLE_ARN"          = var.ManagementAccountRoleArn
      "ACCOUNT_IDS"                          = "None"
      "DEFAULT_CHANNEL"                      = var.default_channel
      CONFIG_SSM_PARAMETER_NAME              = aws_ssm_parameter.config_primary.name
      PARAMETERS_SECRETS_EXTENSION_HTTP_PORT = "2273"
    }
  }

  layers = [var.ssm_lambda_layer_primary]

  timeouts {}

  tracing_config {
    mode = "PassThrough"
  }
  tags = {
    "Name" = "AHA-LambdaFunction"
  }
  depends_on = [
    aws_dynamodb_table.AHA-DynamoDBTable,
    aws_dynamodb_table.AHA-GlobalDynamoDBTable,
  ]
}


resource "aws_ssm_parameter" "config_primary" {
  name  = "/internal/lambda/aws-health-aware/config"
  type  = "String"
  value = jsonencode(var.configuration)
}

resource "aws_ssm_parameter" "config_secondary" {
  name     = "/internal/lambda/aws-health-aware/config"
  type     = "String"
  value    = jsonencode(var.configuration)
  provider = aws.secondary_region
}

# aws_lambda_function - AHA-LambdaFunction - Secondary region
resource "aws_lambda_function" "AHA-LambdaFunction-SecondaryRegion" {
  count            = var.aha_secondary_region == "" ? 0 : 1
  provider         = aws.secondary_region
  description      = "Lambda function that runs AHA"
  function_name    = "AHA-LambdaFunction"
  handler          = "handler.main"
  memory_size      = 128
  timeout          = 600
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  #    s3_bucket                      = var.S3Bucket
  #    s3_key                         = var.S3Key
  reserved_concurrent_executions = -1
  role                           = aws_iam_role.AHA-LambdaExecutionRole.arn
  runtime                        = "python3.12"

  environment {
    variables = {
      "DYNAMODB_TABLE"                       = var.dynamodbtable
      "EVENT_SEARCH_BACK"                    = var.EventSearchBack
      "HEALTH_EVENT_TYPE"                    = var.AWSHealthEventType
      "ORG_STATUS"                           = var.AWSOrganizationsEnabled
      "REGIONS"                              = var.Regions
      "MANAGEMENT_ROLE_ARN"                  = var.ManagementAccountRoleArn
      "EVENT_BUS_NAME"                       = var.EventBusName
      "EVENT_BUS_ENDPOINT"                   = var.EventBusEndpoint
      "MANAGEMENT_ACCOUNT_ROLE_ARN"          = var.ManagementAccountRoleArn
      "ACCOUNT_IDS"                          = "None"
      "DEFAULT_CHANNEL"                      = var.default_channel
      CONFIG_SSM_PARAMETER_NAME              = aws_ssm_parameter.config_secondary.name
      PARAMETERS_SECRETS_EXTENSION_HTTP_PORT = "2273"
    }
  }

  layers = [var.ssm_lambda_layer_secondary]

  tracing_config {
    mode = "PassThrough"
  }
  tags = {
    "Name" = "AHA-LambdaFunction"
  }
  depends_on = [
    aws_dynamodb_table.AHA-DynamoDBTable,
    aws_dynamodb_table.AHA-GlobalDynamoDBTable,
  ]
}

# EventBridge - Schedule to run lambda
resource "aws_cloudwatch_event_rule" "AHA-LambdaSchedule-PrimaryRegion" {
  description         = "Lambda trigger Event"
  event_bus_name      = "default"
  is_enabled          = true
  name                = "AHA-LambdaSchedule"
  schedule_expression = "rate(1 minute)"
  tags = {
    "Name" = "AHA-LambdaSchedule"
  }
}

resource "aws_cloudwatch_event_rule" "AHA-LambdaSchedule-SecondaryRegion" {
  count               = var.aha_secondary_region == "" ? 0 : 1
  provider            = aws.secondary_region
  description         = "Lambda trigger Event"
  event_bus_name      = "default"
  is_enabled          = true
  name                = "AHA-LambdaSchedule"
  schedule_expression = "rate(1 minute)"
  tags = {
    "Name" = "AHA-LambdaSchedule"
  }
}

resource "aws_cloudwatch_event_target" "AHA-LambdaFunction-PrimaryRegion" {
  arn  = aws_lambda_function.AHA-LambdaFunction-PrimaryRegion.arn
  rule = aws_cloudwatch_event_rule.AHA-LambdaSchedule-PrimaryRegion.name
}

resource "aws_cloudwatch_event_target" "AHA-LambdaFunction-SecondaryRegion" {
  count    = var.aha_secondary_region == "" ? 0 : 1
  provider = aws.secondary_region
  arn      = aws_lambda_function.AHA-LambdaFunction-SecondaryRegion[0].arn
  rule     = aws_cloudwatch_event_rule.AHA-LambdaSchedule-SecondaryRegion[0].name
}

resource "aws_lambda_permission" "AHA-LambdaSchedulePermission-PrimaryRegion" {
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  function_name = aws_lambda_function.AHA-LambdaFunction-PrimaryRegion.arn
  source_arn    = aws_cloudwatch_event_rule.AHA-LambdaSchedule-PrimaryRegion.arn
}
resource "aws_lambda_permission" "AHA-LambdaSchedulePermission-SecondaryRegion" {
  count         = var.aha_secondary_region == "" ? 0 : 1
  provider      = aws.secondary_region
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  function_name = aws_lambda_function.AHA-LambdaFunction-SecondaryRegion[0].arn
  source_arn    = aws_cloudwatch_event_rule.AHA-LambdaSchedule-SecondaryRegion[0].arn
}
