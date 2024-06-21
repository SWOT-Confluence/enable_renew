# AWS Lambda function
resource "aws_lambda_function" "aws_lambda_enable_renew" {
  filename         = "enable_renew.zip"
  function_name    = "${var.prefix}-enable-renew"
  role             = aws_iam_role.aws_lambda_enable_renew_execution_role.arn
  handler          = "enable_renew.handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("enable_renew.zip")
  timeout          = 300
  environment {
    variables = {
      ENV_PREFIX = var.prefix
    }
  }
  vpc_config {
    subnet_ids         = data.aws_subnets.private_application_subnets.ids
    security_group_ids = data.aws_security_groups.vpc_default_sg.ids
  }
  file_system_config {
    arn              = data.aws_efs_access_point.fsap_enable_renew.arn
    local_mount_path = "/mnt/data"
  }
  tags = {
    "Name" = "${var.prefix}-enable-renew"
  }
}

# AWS Lambda execution role & policy
resource "aws_iam_role" "aws_lambda_enable_renew_execution_role" {
  name = "${var.prefix}-lambda-enable-renew-execution-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# Execution policy
resource "aws_iam_role_policy_attachment" "aws_lambda_enable_renew_execution_role_policy_attach" {
  role       = aws_iam_role.aws_lambda_enable_renew_execution_role.name
  policy_arn = aws_iam_policy.aws_lambda_enable_renew_execution_policy.arn
}

resource "aws_iam_policy" "aws_lambda_enable_renew_execution_policy" {
  name        = "${var.prefix}-lambda-enable-renew-execution-policy"
  description = "Enable EventBridge schedule."
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowCreatePutLogs",
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:*:*:*"
      },
      {
        "Sid" : "EnableEventBridgeSchedule",
        "Effect" : "Allow",
        "Action" : [
          "scheduler:GetSchedule",
          "scheduler:UpdateSchedule"
        ],
        "Resource" : "arn:aws:scheduler:${var.aws_region}:${local.account_id}:schedule/default/${var.prefix}-renew"
      },
      {
        "Sid" : "IAMPassRole",
        "Effect" : "Allow",
        "Action" : [
          "iam:PassRole"
        ],
        "Resource" : "${data.aws_iam_role.eventbridge_renew_exe_role.arn}"
      },
      {
        "Sid" : "AllowVPCAccess",
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateNetworkInterface"
        ],
        "Resource" : concat([for subnet in data.aws_subnet.private_application_subnet : subnet.arn], ["arn:aws:ec2:${var.aws_region}:${local.account_id}:*/*"])
      },
      {
        "Sid" : "AllowVPCDelete",
        "Effect" : "Allow",
        "Action" : [
          "ec2:DeleteNetworkInterface"
        ],
        "Resource" : "arn:aws:ec2:${var.aws_region}:${local.account_id}:*/*"
      },
      {
        "Sid" : "AllowVPCDescribe",
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeNetworkInterfaces"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "AllowEFSAccess",
        "Effect" : "Allow",
        "Action" : [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:DescribeMountTargets"
        ],
        "Resource" : "${data.aws_efs_access_point.fsap_enable_renew.file_system_arn}"
        "Condition" : {
          "StringEquals" : {
            "elasticfilesystem:AccessPointArn" : "${data.aws_efs_access_point.fsap_enable_renew.arn}"
          }
        }
      },
      {
        "Sid" : "AllowStepFunctions",
        "Effect" : "Allow",
        "Action" : [
          "states:SendTaskFailure",
          "states:SendTaskSuccess"
        ],
        "Resource" : "arn:aws:states:${var.aws_region}:${local.account_id}:stateMachine:${var.prefix}-workflow"
      },
      {
        "Sid" : "AllowListAllBuckets",
        "Effect" : "Allow",
        "Action" : "s3:ListAllMyBuckets",
        "Resource" : "*"
      },
      {
        "Sid" : "AllowListBuckets",
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ],
        "Resource" : [
          "${data.aws_s3_bucket.confluence_json.arn}"
        ]
      },
      {
        "Sid" : "AllGetPutObjects",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetObjectAttributes",
          "s3:ListMultipartUploadParts"
        ],
        "Resource" : [
          "${data.aws_s3_bucket.confluence_json.arn}/*"
        ]
      }
    ]
  })
}
