output "lb_ip" {
  description = "Load Balancer external IP"
  value       = google_compute_global_address.default.address
}
