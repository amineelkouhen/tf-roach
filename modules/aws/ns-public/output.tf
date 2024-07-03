output "cluster_master_dns" {
  value = "${var.subdomain}.cluster.${var.hosted_zone}"
}