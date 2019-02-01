variable "vsphere_user" {
  description = "Vsphere user name, eg. administrator@vsphere.local"
}

variable "vsphere_password" { }
variable "vsphere_server"   { }

variable "network_dns"     { default = "8.8.8.8" }
variable "network_address" { }
variable "network_gateway" { default = "192.168.0.1" }

variable "vsphere_datacenter"         { }
variable "vsphere_datastore_name"     { }
variable "vsphere_network_name"       { }
variable "vsphere_resource_pool_name" { }

variable "virtual_machine_template_name" {  default = "coreos-stable" }

variable "virtual_machine_name" { }
variable "num_cpus"             { default = "1" }
variable "memory"               { default = "512" }
variable "disk_size"            { default = "8" }

variable "domain_name" { default = "" }

variable "notifications_endpoints_name"     { default = "" }
variable "notifications_endpoints_disabled" { default = "true" }
variable "notifications_endpoints_url"      { default = "" }


# Terraform Backend variables
# NOTE Backend modules have no interpolation due to their early loading.
# Leaving here for reference
#
# variable "aws_access_key_id"     {  }
# variable "aws_secret_access_key" {  }
# variable "aws_region"            { default = "us-east-1" }
#
# variable "s3_bucket"  { }
