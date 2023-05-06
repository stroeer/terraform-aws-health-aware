
# IAM Role for Lambda function execution
resource "aws_iam_role" "AHA-LambdaExecutionRole" {
  name = "AHA-LambdaExecutionRole"
  path = "/"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "lambda.amazonaws.com"
          }
        },
      ]
    }
  )
  inline_policy {
    name   = "AHA-LambdaPolicy"
    policy = data.aws_iam_policy_document.AHA-LambdaPolicy-Document.json
  }
  tags = {
    "Name" = "AHA-LambdaExecutionRole"
  }
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "AHA-LambdaPolicy-Document" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${var.aha_primary_region}:${data.aws_caller_identity.current.account_id}:*",
      "arn:aws:logs:${local.secondary_region}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "health:DescribeAffectedAccountsForOrganization",
      "health:DescribeAffectedEntitiesForOrganization",
      "health:DescribeEventDetailsForOrganization",
      "health:DescribeEventsForOrganization",
      "health:DescribeEventDetails",
      "health:DescribeEvents",
      "health:DescribeEventTypes",
      "health:DescribeAffectedEntities",
      "organizations:ListAccounts",
      "organizations:DescribeAccount",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:ListTables",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aha_primary_region}:${data.aws_caller_identity.current.account_id}:*",
      "arn:aws:dynamodb:${local.secondary_region}:${data.aws_caller_identity.current.account_id}:*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ses:SendEmail",
    ]
    resources = [
      "arn:aws:ses:${var.aha_primary_region}:${data.aws_caller_identity.current.account_id}:*",
      "arn:aws:ses:${local.secondary_region}:${data.aws_caller_identity.current.account_id}:*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:UpdateTimeToLive",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
      "dynamodb:UpdateTable",
      "dynamodb:GetRecords",
    ]
    resources = [
      #aws_dynamodb_table.AHA-DynamoDBTable.arn
      "arn:aws:dynamodb:${var.aha_primary_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodbtable}",
      "arn:aws:dynamodb:${local.secondary_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodbtable}",
    ]
  }


  dynamic "statement" {
    for_each = var.ManagementAccountRoleArn == "" ? [] : [1]
    content {
      effect = "Allow"
      actions = [
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds",
        "secretsmanager:GetSecretValue",
      ]
      resources = [
        aws_secretsmanager_secret.AssumeRoleArn[0].arn,
        "arn:aws:secretsmanager:${local.secondary_region}:${data.aws_caller_identity.current.account_id}:secret:${element(split(":", aws_secretsmanager_secret.AssumeRoleArn[0].arn), 6)}"
      ]
    }
  }
  dynamic "statement" {
    for_each = var.EventBusName == "" ? [] : [1]
    content {
      effect = "Allow"
      actions = [
        "events:PutEvents",
      ]
      resources = [
        "arn:aws:events:${var.aha_primary_region}:${data.aws_caller_identity.current.account_id}:event-bus/${var.EventBusName}",
        "arn:aws:events:${local.secondary_region}:${data.aws_caller_identity.current.account_id}:event-bus/${var.EventBusName}"
      ]
    }
  }
  dynamic "statement" {
    for_each = var.ManagementAccountRoleArn == "" ? [] : [1]
    content {
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      resources = [
        var.ManagementAccountRoleArn,
      ]
    }
  }

  dynamic "statement" {
    for_each = var.configuration == "" ? [] : [1]
    content {
      effect    = "Allow"
      actions   = ["ssm:GetParameter"]
      resources = [aws_ssm_parameter.config_primary.arn, aws_ssm_parameter.config_secondary.arn]
    }
  }
}
