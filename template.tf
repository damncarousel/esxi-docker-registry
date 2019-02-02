data "vsphere_virtual_machine" "template" {
  name          = "${var.virtual_machine_template_name}"
  datacenter_id = "${data.vsphere_datacenter.default.id}"
}
