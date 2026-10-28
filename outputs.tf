output "services" {
  description = "The systemd service of each container, by container name."
  value       = { for name, _ in var.containers : name => "${name}.service" }
}
