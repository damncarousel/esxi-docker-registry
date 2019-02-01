data "vsphere_network" "default" {
  name          = "${var.vsphere_network_name}"
  datacenter_id = "${data.vsphere_datacenter.default.id}"
}
