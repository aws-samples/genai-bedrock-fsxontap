
resource "aws_ecr_repository" "fsxnragvector" {
  name                 = "fsxnragvector"
  image_tag_mutability = "MUTABLE"
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "fsxnragembed" {
  name                 = "fsxnragembed"
  image_tag_mutability = "MUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "fsxnragchat" {
  name                 = "fsxnragchat"
  image_tag_mutability = "MUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_ecr_authorization_token" "token" {}

# configure docker provider
provider "docker" {
  registry_auth {
      address = data.aws_ecr_authorization_token.token.proxy_endpoint
      username = data.aws_ecr_authorization_token.token.user_name
      password  = data.aws_ecr_authorization_token.token.password
    }
}

# build docker image
resource "docker_image" "lambda-image" {
  name = "${aws_ecr_repository.fsxnragvector.repository_url}:latest"
  platform = "linux/amd64"
  build {
    context = "../lambda"
    tag = ["${aws_ecr_repository.fsxnragvector.repository_url}:latest"]
    platform = "linux/amd64"
    no_cache = true
  }
}

# build docker image
resource "docker_image" "embed-image" {
  name = "${aws_ecr_repository.fsxnragembed.repository_url}:latest"
  platform = "linux/amd64"
  build {
    context = "../embed"
    tag = ["${aws_ecr_repository.fsxnragembed.repository_url}:latest"]
    platform = "linux/amd64"
    no_cache = true
  }
}

resource "docker_image" "chat-image" {
  name = "${aws_ecr_repository.fsxnragchat.repository_url}:latest"
  platform = "linux/amd64"
  build {
    context = "../chatapp"
    tag = ["${aws_ecr_repository.fsxnragchat.repository_url}:latest"]
    platform = "linux/amd64"
    no_cache = true
  }
}
# push image to ecr repo
resource "docker_registry_image" "push-rag-image" {
  name = docker_image.lambda-image.name
}

# push image to ecr repo
resource "docker_registry_image" "push-embed-image" {
  name = docker_image.embed-image.name
}

resource "docker_registry_image" "push-chat-image" {
  name = docker_image.chat-image.name
}

