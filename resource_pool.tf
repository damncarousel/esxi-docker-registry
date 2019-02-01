data "vsphere_resource_pool" "default" {
  name          = "${var.vsphere_resource_pool_name}"
  datacenter_id = "${data.vsphere_datacenter.default.id}"
}
