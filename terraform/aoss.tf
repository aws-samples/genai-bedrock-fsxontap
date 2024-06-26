resource "aws_opensearchserverless_security_policy" "aoss_network_policy" {
  name = "fsxnragvector"
  type = "network"
  policy = jsonencode([
    {
      Description = "Allow access to the collection and dashboard",
      Rules = [
        {
          Resource = [
            "collection/${var.collection_name}"
          ],
          ResourceType = "collection"
        },
        {
          Resource = [
            "collection/${var.collection_name}"
          ],
          ResourceType = "dashboard"
        }
      ],
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_security_policy" "aoss_encryption_policy" {
  name = "fsxnragvector"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        Resource = [
          "collection/${var.collection_name}"
        ],
        ResourceType = "collection"
      }
    ],
    AWSOwnedKey = true
  })
}


resource "aws_opensearchserverless_access_policy" "fsxnragvector" {
  name        = "fsxnragvector"
  type        = "data"
  description = "read and write permissions"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index",
          Resource = [
            "index/${var.collection_name}/*"
          ],
          Permission = [
            "aoss:*"
          ]
        },
        {
          ResourceType = "collection",
          Resource = [
            "collection/${var.collection_name}"
          ],
          Permission = [
            "aoss:*"
          ]
        }
      ],
      Principal = [
        data.aws_caller_identity.current.arn,
        aws_iam_role.lambda_bedrock_rag_retreival_role.arn,
        aws_iam_role.ec2_embedding_role.arn
      ]
    }
  ])
}

resource "aws_opensearchserverless_collection" "fsxnragvector" {
  name = var.collection_name
  standby_replicas = "DISABLED"
  type = "VECTORSEARCH"

  depends_on = [aws_opensearchserverless_security_policy.aoss_encryption_policy,
                aws_opensearchserverless_security_policy.aoss_network_policy]
}
