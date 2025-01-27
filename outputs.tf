
output "instance_id" {
  value = aws_instance.vpn.id
}

output "vpn_details" {
  value = aws_eip.eip
}
