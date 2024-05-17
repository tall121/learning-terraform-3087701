data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}
module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "Dev"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  #private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  #enable_nat_gateway = true
  #enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}
resource "aws_instance" "web" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
  vpc_security_group_ids=[module.blog_sg.security_group_id]
  subnet_id=module.blog_vpc.public_subnets[0]
  tags = {
    Name = "HelloWorld"
  }
}

module "blog_alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets
  security_groups =module.sg.security_group_id

  access_logs = {
    bucket = "blog-alb-logs"
  }

  listeners = {
    ex-http-https-redirect = {
      port     = 80
      protocol = "HTTP"
      
    }
   
    
  }

  target_groups = {
    ex-instance = {
      name_prefix      = "blog-http"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      targets = {
        my_target ={
          target_id=aws_instance.blog.id
        }
      }
    }
  }

  tags = {
    Environment = "Dev"
    #Project     = "Example"
  }
}
module "blog_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "blog-service"
  description = "Allow web traffic"
  vpc_id      = module.blog_vpc.vpc_id
  
  
  ingress_rules            = ["https-443-tcp","http-80-tcp"]
  ingress_cidr_blocks      = ["0.0.0.0/0"]
  
  egress_rules            = ["all-all"]
  egress_cidr_blocks      = ["0.0.0.0/0"]
}
