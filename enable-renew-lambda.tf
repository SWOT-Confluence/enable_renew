# AWS Lambda function
resource "aws_lambda_function" "aws_lambda_enable_renew" {
  filename         = "enable_renew.zip"
  function_name    = "${var.prefix}-enable-renew"
  role             = aws_iam_role.aws_lambda_enable_renew_execution_role.arn
  handler          = "enable_renew.handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("enable_renew.zip")
  timeout          = 300
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
      }
    ]
  })
}
