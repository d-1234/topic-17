output "lambda_role_arn" { value = aws_iam_role.lambda.arn }
output "sfn_role_arn" { value = aws_iam_role.sfn.arn }
output "eventbridge_role_arn" { value = aws_iam_role.eventbridge.arn }
output "kms_key_arn" { value = aws_kms_key.main.arn }
