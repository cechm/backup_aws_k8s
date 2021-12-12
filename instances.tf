#Get latest RHEL8 AMI image  in eu-central-1
data "aws_ami" "rhel8" {
  provider = aws.region-master
  most_recent = true

  filter {
    name   = "name"
    values = ["RHEL-8*HVM-*Hourly*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  owners = ["309956199498"] # Red Hat
}

#Create key-pair for logging into EC2 in eu-central-1
resource "aws_key_pair" "master-key" {
  provider   = aws.region-master
  key_name   = "k8srsa"
  public_key = file("~/.ssh/id_rsa.pub")
}

#Create and bootstrap EC2 RHEL8 K8sMaster node in eu-central-1
resource "aws_instance" "K8s-master" {
  provider                    = aws.region-master
  ami                         = data.aws_ami.rhel8.id
  instance_type               = var.instance-type
  key_name                    = aws_key_pair.master-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.k8s-sg.id]
  subnet_id                   = aws_subnet.subnet_1.id
  provisioner "local-exec" {
    command = <<EOF
aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-master} --instance-ids ${self.id} \
&& ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name}' ansible_templates/install_K8sMaster.yaml
EOF
  }
  tags = {
    Name = "K8s_master_tf"
  }
  depends_on = [aws_main_route_table_association.set-master-default-rt-assoc]
}

#Create and bootstrap EC2 RHEL8 K8sWorker node in eu-central-1
resource "aws_instance" "K8s-worker" {
  provider                    = aws.region-master
  ami                         = data.aws_ami.rhel8.id
  instance_type               = var.instance-type
  key_name                    = aws_key_pair.master-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.k8s-sg.id]
  subnet_id                   = aws_subnet.subnet_2.id
  provisioner "local-exec" {
    command = <<EOF
aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-master} --instance-ids ${self.id} \
&& ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name}' ansible_templates/install_K8sWorker.yaml
EOF
  }
  tags = {
    Name = "K8s_worker_tf"
  }
  depends_on = [aws_main_route_table_association.set-master-default-rt-assoc]
}

