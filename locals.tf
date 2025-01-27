locals {
  prefix      = "vpn"
  name_prefix = "vpn"

  aws = {
    region     = data.aws_region.current.name
    account_id = data.aws_caller_identity.current.account_id
  }

  vpn_user_data = <<-EOF
#!/usr/bin/env sh

set -e

################################################################################
### Start SSM Agent
################################################################################
sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

################################################################################
################################################################################
echo "${local.name_prefix}" > /etc/hostname
hostname "${local.name_prefix}"

# pritunl installation part goes here
echo "Pritunl Installing"
apt update
apt install wget unzip curl jq -y

echo "Downloading AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
aws --version

################################################################################
## efs install/configure block
################################################################################
apt-get -y install git binutils nfs-common

# Mount EFS with necessary permission
mkdir -p /var/lib/mongodb

until sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.efs.dns_name}:/ /var/lib/mongodb; do echo "wait and retry for efs: ${aws_efs_file_system.efs.dns_name} to be ready..."; sleep 10; done
sudo echo "${aws_efs_file_system.efs.dns_name}:/ /mnt/efs_mount_point efs _netdev,noresvport,tls,accesspoint=${aws_efs_access_point.access_point.id} 0 0"  >> /etc/fstab


# until mount -t efs ${aws_efs_file_system.efs.id}:/ /var/lib/mongodb; do echo "wait and retry for efs: ${aws_efs_file_system.efs.id} to be ready..."; sleep 10; done
# echo "${aws_efs_file_system.efs.id} /var/lib/mongodb efs _netdev,noresvport,tls,accesspoint=${aws_efs_access_point.access_point.id} 0 0"  >> /etc/fstab


groupadd -g 2000 -r mongodb && useradd -r -g mongodb -u 2000 mongodb
chown -R mongodb:mongodb /var/lib/mongodb

################################################################################
## elivate limits
################################################################################
echo "* hard nofile 64000" >> /etc/security/limits.conf
echo "* soft nofile 64000" >> /etc/security/limits.conf
echo "root hard nofile 64000" >> /etc/security/limits.conf
echo "root soft nofile 64000" >> /etc/security/limits.conf

echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org.list

echo "deb [signed-by=/usr/share/keyrings/openvpn-repo.gpg] https://build.openvpn.net/debian/openvpn/stable jammy main" | sudo tee /etc/apt/sources.list.d/openvpn.list

echo "deb [ signed-by=/usr/share/keyrings/pritunl.gpg ] https://repo.pritunl.com/stable/apt jammy main" | sudo tee /etc/apt/sources.list.d/pritunl.list

sudo apt --assume-yes install gnupg

curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor --yes
curl -fsSL https://swupdate.openvpn.net/repos/repo-public.gpg | sudo gpg -o /usr/share/keyrings/openvpn-repo.gpg --dearmor --yes
curl -fsSL https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc | sudo gpg -o /usr/share/keyrings/pritunl.gpg --dearmor --yes
sudo apt update
sudo apt --assume-yes install pritunl openvpn mongodb-org wireguard wireguard-tools

sudo ufw disable

echo "mongodb-org hold" | dpkg --set-selections
echo "mongodb-org-database hold" | dpkg --set-selections
echo "mongodb-org-server hold" | dpkg --set-selections
echo "mongodb-mongosh hold" | dpkg --set-selections
echo "mongodb-org-mongos hold" | dpkg --set-selections
echo "mongodb-org-tools hold" | dpkg --set-selections

sudo systemctl start pritunl mongod
sudo systemctl enable pritunl mongod

################################################################################
## Override mongod.service to start after fs mount
################################################################################
sudo mkdir -p /etc/systemd/system/mongod.service.d
sudo tee /etc/systemd/system/mongod.service.d/override.conf <<-TEMPLATE
[Unit]
After=
After=remote-fs.target
TEMPLATE

sudo systemctl daemon-reload

################################################################################
## log rotation if needed
################################################################################
cat <<-TEMPLATE > /etc/logrotate.d/mongodb
/var/log/mongodb/*.log {
  daily
  missingok
  rotate 60
  compress
  delaycompress
  copytruncate
  notifempty
}
TEMPLATE

EOF
}
