resource "aws_dynamodb_table" "session-table" {
  name           = "SessionTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "SessionId"

  attribute {
    name = "SessionId"
    type = "S"
  }
}