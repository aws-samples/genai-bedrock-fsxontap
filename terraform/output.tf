output "lb-dns-name" {
  value = aws_lb.chat_load_balancer.dns_name
}

output "aoss_host" {
  value = aws_opensearchserverless_collection.fsxnragvector.collection_endpoint
}

output "fsx-management-ip" {
  value = aws_fsx_ontap_file_system.bedrockfs.endpoints[0].management[0].ip_addresses
}

output "fsx-secret-id" {
  value = aws_secretsmanager_secret.fsxn_password_secret.id
}

output "fsx-svm-smb-dns-name" {
  value = aws_fsx_ontap_storage_virtual_machine.bedrocksvm.endpoints[0].smb[0].dns_name
}

output "api-invole-url" {
  value = aws_api_gateway_stage.stage.invoke_url
}

