terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -------------------------------------------------------------------
# Locals: use Terraform workspaces as environments (dev / prod)
# -------------------------------------------------------------------
locals {
  # If workspace is "default", treat it as "dev" to avoid ugly names
  env = terraform.workspace != "default" ? terraform.workspace : "dev"

  # All resource names must start with cet11-grp1
  name_prefix = "cet11-grp1-${local.env}"

  iot_topic = "cet11/grp1/${local.env}/telemetry"
}

# -------------------------------------------------------------------
# Basic Networking: VPC + public subnets (not strictly required by IoT,
# but created as requested; you can attach future EC2/Lambda here)
# -------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${local.name_prefix}-vpc"
    Environment = local.env
    Project     = "cet11-grp1-iot-alert"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${local.name_prefix}-igw"
    Environment = local.env
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.name_prefix}-public-a"
    Environment = local.env
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.name_prefix}-public-b"
    Environment = local.env
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${local.name_prefix}-public-rt"
    Environment = local.env
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# -------------------------------------------------------------------
# SNS Topic + Email Subscription
# -------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts-topic"

  tags = {
    Name        = "${local.name_prefix}-alerts-topic"
    Environment = local.env
    Project     = "cet11-grp1-iot-alert"
  }
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "perseverancejb@hotmail.com"
}

# NOTE:
# SNS will send a confirmation email to perseverancejb@hotmail.com.
# You MUST confirm the subscription once to start receiving alerts.

# -------------------------------------------------------------------
# IAM Role & Policy for Lambda
# -------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid    = "AllowSnsPublish"
    effect = "Allow"

    actions = [
      "sns:Publish"
    ]

    resources = [
      aws_sns_topic.alerts.arn
    ]
  }
}

resource "aws_iam_role_policy" "lambda_policy_attach" {
  name   = "${local.name_prefix}-lambda-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# -------------------------------------------------------------------
# Lambda function (Python) to send SNS alerts
# -------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/build/${local.name_prefix}-lambda.zip"
}

resource "aws_lambda_function" "iot_alert" {
  function_name = "${local.name_prefix}-iot-alert-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ALERT_TOPIC_ARN = aws_sns_topic.alerts.arn
      MIN_TEMP        = "25"
      MAX_TEMP        = "40"
    }
  }

  # no VPC attachment for simplicity; Lambda can still publish to SNS
  # If you want Lambda inside the VPC, add vpc_config + NAT/VPC endpoint.

  tags = {
    Name        = "${local.name_prefix}-iot-alert-lambda"
    Environment = local.env
    Project     = "cet11-grp1-iot-alert"
  }
}

# -------------------------------------------------------------------
# Allow IoT Core to invoke the Lambda function
# -------------------------------------------------------------------
resource "aws_lambda_permission" "allow_iot" {
  statement_id  = "AllowExecutionFromIotCore"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.iot_alert.function_name
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.temperature_alert_rule.arn
}

# -------------------------------------------------------------------
# IoT Topic Rule – triggers Lambda on telemetry messages
# -------------------------------------------------------------------
resource "aws_iot_topic_rule" "temperature_alert_rule" {
  name        = "${local.name_prefix}-iot-topic-rule"
  description = "Trigger Lambda when IoT telemetry messages arrive"
  enabled     = true

  # Device publishes JSON messages to this MQTT topic:
  #   cet11/grp1/dev/telemetry   or
  #   cet11/grp1/prod/telemetry
  #
  # Example payload:
  #   { "deviceId": "sensor-1", "temperature": 42.5 }

  sql         = "SELECT * FROM '${local.iot_topic}'"
  sql_version = "2016-03-23"

  lambda {
    function_arn = aws_lambda_function.iot_alert.arn
  }

  tags = {
    Name        = "${local.name_prefix}-iot-topic-rule"
    Environment = local.env
    Project     = "cet11-grp1-iot-alert"
  }
}

# -------------------------------------------------------------------
# (Optional) IoT Policy for your simulated device – attach manually
# -------------------------------------------------------------------
data "aws_iam_policy_document" "iot_policy_doc" {
  statement {
    effect = "Allow"

    actions = [
      "iot:Connect",
      "iot:Publish",
      "iot:Subscribe",
      "iot:Receive"
    ]

    resources = ["*"]
  }
}

resource "aws_iot_policy" "device_policy" {
  name   = "${local.name_prefix}-device-policy"
  policy = data.aws_iam_policy_document.iot_policy_doc.json
}

resource "aws_security_group" "simulator_ec2_sg" {
  name        = "${local.name_prefix}-sim-ec2-sg"
  description = "Security group for cet11-grp1 IoT simulator EC2"
  vpc_id      = aws_vpc.main.id

  # Allow SSH from your IP (RECOMMENDED: replace 0.0.0.0/0 with your IP range)
  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-sim-ec2-sg"
    Environment = local.env
    Project     = "cet11-grp1-iot-alert"
  }
}

data "aws_ami" "ubuntu_latest" {
  most_recent = true

  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "simulator_ec2" {
  ami                         = data.aws_ami.ubuntu_latest.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public_a.id
  associate_public_ip_address = true
  key_name                    = var.ec2_key_name

  vpc_security_group_ids = [
    aws_security_group.simulator_ec2_sg.id
  ]

  tags = {
    Name        = "${local.name_prefix}-sim-ec2"
    Environment = local.env
    Role        = "cet11-grp1-iot-simulator"
    Project     = "cet11-grp1-iot-alert"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -xe

              apt-get update -y
              apt-get install -y git python3 python3-pip

              mkdir -p /opt
              cd /opt

              # Clone or update the app repo
              if [ ! -d "cet11-grp1-iot-simulator" ]; then
                git clone "${var.app_repo_url}" cet11-grp1-iot-simulator
              else
                cd cet11-grp1-iot-simulator
                git pull
              fi

              cd /opt/cet11-grp1-iot-simulator

              pip3 install -r requirements.txt

              # Create systemd service for simulator (dev by default)
              cat >/etc/systemd/system/cet11-grp1-iot-simulator.service <<'UNIT'
              [Unit]
              Description=cet11-grp1 IoT Simulator
              After=network.target

              [Service]
              Type=simple
              WorkingDirectory=/opt/cet11-grp1-iot-simulator
              ExecStart=/usr/bin/python3 src/simulator.py \\
                --endpoint YOUR_IOT_ENDPOINT_HERE \\
                --cert /opt/cet11-grp1-iot-simulator/certs/device-cert.pem.crt \\
                --key /opt/cet11-grp1-iot-simulator/certs/private.pem.key \\
                --root-ca /opt/cet11-grp1-iot-simulator/certs/AmazonRootCA1.pem \\
                --environment dev \\
                --multi-devices 3 \\
                --interval 5
              Restart=always
              RestartSec=5

              [Install]
              WantedBy=multi-user.target
              UNIT

              systemctl daemon-reload
              systemctl enable cet11-grp1-iot-simulator.service
              # Don't start until you've copied certs & updated endpoint
              EOF
}


# You will still need to:
# - create an IoT certificate (in console or via CLI),
# - attach this policy to the certificate,
# - register a Thing,
# - use that cert/key from your simulator to publish telemetry.

