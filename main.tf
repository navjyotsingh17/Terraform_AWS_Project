# Here I am creating a vpc and attaching a CIRD from varibales.tf file
resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

# Here I am creating a subnet inside myvpc, giving it a ip range, creating the subnet in ap-south-1a availability zone and assigning public ip address
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

# Here I am creating a subnet inside myvpc, giving it a ip range, creating the subnet in ap-south-1b availability zone and assigning public ip address
resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}

# Here I am creating a internet gateway so that internet traffic can flow through the VPC
resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.myvpc.id
}

# Here I am creating a route table in myvpc, route table takes care of how the traffic has to flow inside the subnet
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gateway.id
  }
}

# associating route table with subnet 1 
resource "aws_route_table_association" "route_table_association_1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.my_route_table.id
}

# associating route table with subnet 2
resource "aws_route_table_association" "route_table_association_2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.my_route_table.id
}

# creating security group
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  tags = {
    Name = "web_sg"
  }
}

# creating ingress rule for all http inbound traffic
resource "aws_vpc_security_group_ingress_rule" "allow_traffic_http" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# creating ingress rule for all ssh inbound traffic
resource "aws_vpc_security_group_ingress_rule" "allow_traffic_ssh" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# creating egress rule for all outbound traffic
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# creating S3 bucket
resource "aws_s3_bucket" "navjyots_bucket" {
  bucket = "navjyot-tf-test-bucket"
}

# creating a EC2 instance
resource "aws_instance" "web_server1" {
  ami                    = "ami-07a00cf47dbbc844c"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = aws_subnet.subnet_1.id
  user_data_base64       = base64encode(file("user_data_1.sh"))
}

# creating a EC2 instance
resource "aws_instance" "web_server2" {
  ami                    = "ami-07a00cf47dbbc844c"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = aws_subnet.subnet_2.id
  user_data_base64       = base64encode(file("user_data_2.sh"))
}

# creating a Load balancer
resource "aws_lb" "my_lb" {
  name               = "my-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  tags = {
    Environment = "dev"
  }
}

# creating target group for load balancer, so that request will come to target group and then request will go to load balancer, then load balancer will forward that request to ec2 instances
resource "aws_lb_target_group" "lb_target_group" {
  name     = "my-lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

# attaching lb target group attachment to ec2 instance
resource "aws_lb_target_group_attachment" "target_group_attachment_1" {
  target_group_arn = aws_lb_target_group.lb_target_group.arn
  target_id        = aws_instance.web_server1.id
  port             = 80
}

# attaching lb target group attachment to ec2 instance
resource "aws_lb_target_group_attachment" "target_group_attachment_2" {
  target_group_arn = aws_lb_target_group.lb_target_group.arn
  target_id        = aws_instance.web_server2.id
  port             = 80
}

# creating lb listener to forward the request to lb target group
resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.my_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.lb_target_group.arn
    type             = "forward"
  }
}

# here I am printing the load balancer dns i.e ip in terminal
output "load_balancer_dns" {
  value = aws_lb.my_lb.dns_name
}