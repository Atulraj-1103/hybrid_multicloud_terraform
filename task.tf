provider "aws" {
  region     = "ap-south-1"
  profile    = "myprofile"
}

variable "mykey" {
  type = string
  default = "mykey111"	
}
resource "aws_security_group" "httpd_web" {
  name        = "task1_sg" //give this name to instance
  description = "Allow httpd inbound traffic"
  
  ingress {
    description = "httpd_port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "ssh_port"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "default"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
egress {
    description = "default1"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "httpd_web"
  }
}
resource "aws_instance" "web_auto" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = var.mykey
  security_groups = [ "task1_sg" ] 
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/KIIT/Desktop/terraform/mykey111.pem")
    host     = aws_instance.web_auto.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "web_auto"
  }
}

resource "aws_ebs_volume" "task_volume" {
  availability_zone = aws_instance.web_auto.availability_zone
  size              = 1
  tags = {
      Name = "task_volume"
   }
}
 
resource "aws_volume_attachment" "task_ebs" {
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.task_volume.id
  instance_id = aws_instance.web_auto.id
  force_detach = true
}

resource "null_resource" "nullremote"  {

depends_on = [
    aws_volume_attachment.task_ebs,
  ]

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/KIIT/Desktop/terraform/mykey111.pem")
    host     = aws_instance.web_auto.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdd",
      "sudo mount  /dev/xvdd  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Atulraj-1103/hybrid_multicloud_terraform.git /var/www/html/"
    ]
  }
}


resource "null_resource" "null1"{
  provisioner "local-exec" {
    command = "git clone https://github.com/Atulraj-1103/hybrid_multicloud_terraform.git ./gitcode1"
  }
}

resource "aws_s3_bucket" "raj830241" {
  bucket = "raj830241"
  acl    = "public-read-write"

  tags = {
    Name        = "raj830241"
    Environment = "Dev"
  }
}
resource "aws_s3_bucket_object" "raj_object" {
  bucket = aws_s3_bucket.raj830241.id
  key    = "nature.jpg"
  source = "./gitcode1/nature.jpg"
  acl    = "public-read-write"
  
}

locals {
  s3_origin_id = "${aws_s3_bucket.raj830241.bucket}"
}

//cloud front 

resource "aws_cloudfront_distribution" "auto_cfd" {
  origin {
    domain_name = aws_s3_bucket.raj830241.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "s3 is its origin"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.raj830241.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

    restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

  tags = {
    Name = "web_distribution"
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  depends_on = [ aws_s3_bucket.raj830241,
    ]
}















