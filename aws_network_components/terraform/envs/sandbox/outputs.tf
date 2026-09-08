# Add output blocks here as you add modules in main.tf.
# After Day 1, uncomment these:
#
# output "shared_services_vpc_id" {
#   value = module.shared_services_vpc.vpc_id
# }
#
# output "shared_services_private_subnet_ids" {
#   value = module.shared_services_vpc.private_subnet_ids
# }
#
# From Day 2 onward the EC2 test harness outputs are what you use constantly.
# one() returns null instead of erroring when the module is disabled:
#
# output "ec2_test_shared_services_ids" {
#   value = one(module.ec2_test_shared_services[*].instance_ids)
# }
#
# output "ec2_test_shared_services_ips" {
#   value = one(module.ec2_test_shared_services[*].private_ips)
# }
#
# output "ec2_test_app_ids" {
#   value = one(module.ec2_test_app[*].instance_ids)
# }
#
# output "ec2_test_app_ips" {
#   value = one(module.ec2_test_app[*].private_ips)
# }
