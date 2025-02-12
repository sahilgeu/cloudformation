provider "aws" {
region = "ap-south-1"
}

resource "aws_cloudformation_stack" "network" {
  name = "networking-stack"
  template_body = file("${path.module}/cloudformation/file1.yaml")
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

}
