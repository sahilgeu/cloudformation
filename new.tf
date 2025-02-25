provider "aws" {
  region     = "ap-south-1"  # Modify as per your region
  access_key = 
  secret_key = "
}

# Create an S3 bucket
resource "aws_s3_bucket" "awscli_bucket" {
  bucket = "my-awscli-bucket-12345"  # Change to a globally unique bucket name

  tags = {
    Name        = "AWSCLI Bucket"
    Environment = "Dev"
  }
}


# Upload the AWS CLI installer to S3
resource "aws_s3_object" "awscli_upload" {
  bucket = aws_s3_bucket.awscli_bucket.bucket
  key    = "awscliv2.zip"
  source = "awscliv2.zip"  # Ensure this file is in the same directory as Terraform
 }


# Create an IAM policy with the provided S3 permissions
resource "aws_iam_policy" "s3_access_policy" {
  name        = "EC2-S3-Access-Policy"
  description = "Policy to allow EC2 to access specific S3 bucket operations"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObjectAcl",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "arn:aws:s3:::my-cli-bucket123333",        # The bucket itself
          "arn:aws:s3:::my-cli-bucket123333/*"       # All objects within the bucket
        ]
        Effect = "Allow"
      }
    ]
  })
}

# Create an IAM role for EC2 that allows it to assume the role
resource "aws_iam_role" "ec2_s3_access_role" {
  name               = "EC2-S3-Access-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect   = "Allow"
        Sid      = ""
      }
    ]
  })
}

# Attach the S3 access policy to the IAM role
resource "aws_iam_role_policy_attachment" "s3_access_policy_attachment" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Attach the SSM policy to the IAM role
resource "aws_iam_role_policy_attachment" "ssm_access_policy_attachment" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec21_s3_access_profile" {
  name = "EC2-S3-Access-Profile1"
  role = aws_iam_role.ec2_s3_access_role.name
}

# Create a security group to allow RDP access to Windows EC2 instance
resource "aws_security_group" "ec2_sg" {
  name        = "EC2-SG"
  description = "Allow RDP access to Windows EC2 instance"

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Update for tighter security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "my_key" {
  key_name   = "my-key-pair"
  public_key = file("my-key-pair.pem.pub")  # Path to your public key
}


# Launch Windows EC2 instance
resource "aws_instance" "winstance" {
  ami                  = "ami-05a00967f06885a63"  # Use the latest Windows Server AMI for your region
  instance_type        = "t3.micro"  # Modify as per your needs
  key_name = aws_key_pair.my_key.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec21_s3_access_profile.name

user_data = <<-EOF
  <powershell>

  # Load AWS PowerShell modules
Import-Module AWSPowerShell

# Define S3 bucket and key details
$bucketName = "my-awscli-bucket-12345"
$s3Key = "awscliv2.zip"
$localZipFile = "C:\Temp\file.zip"
$installDirectory = "C:\Install"

# Ensure the Temp directory exists
if (!(Test-Path -Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp" | Out-Null
}

# Ensure the Install directory exists
if (!(Test-Path -Path $installDirectory)) {
    New-Item -ItemType Directory -Path $installDirectory | Out-Null
}

# Download zip file from S3
try {
    Get-S3Object -BucketName $bucketName -Key $s3Key -FilePath $localZipFile -ErrorAction Stop
    Write-Host "Download successful: $localZipFile"
} catch {
    Write-Host "Failed to download file from S3: $_"
    exit 1
}

# Extract the zip file
try {
    Expand-Archive -Path $localZipFile -DestinationPath $installDirectory -Force
    Write-Host "Extraction successful to: $installDirectory"
} catch {
    Write-Host "Failed to extract file: $_"
    exit 1
}

# Optional: Run installation script if needed
$installScript = "$installDirectory\install.ps1"
if (Test-Path -Path $installScript) {
    try {
        Write-Host "Running installation script: $installScript"
        & $installScript
        Write-Host "Installation script executed successfully."
    } catch {
        Write-Host "Failed to execute installation script: $_"
        exit 1
    }
} else {
    Write-Host "No installation script found."
}

</powershell>
EOF

  tags = {
    Name = "Windows-EC2"
}
}
