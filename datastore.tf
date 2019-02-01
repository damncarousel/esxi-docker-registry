data "vsphere_datastore" "default" {
  name          = "${var.vsphere_datastore_name}"
  datacenter_id = "${data.vsphere_datacenter.default.id}"
}
