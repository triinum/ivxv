output "endpoint" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "uri_template" {
  description = "Fill PASSWORD; use as technical.storage.conf.URI"
  value       = "postgres://${var.username}:PASSWORD@${aws_db_instance.this.address}:${aws_db_instance.this.port}/${var.db_name}?sslmode=require"
}
