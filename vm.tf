resource "vsphere_virtual_machine" "default" {
  name = "${var.virtual_machine_name}"

  resource_pool_id = "${data.vsphere_resource_pool.default.id}"
  datastore_id     = "${data.vsphere_datastore.default.id}"
  num_cpus         = "${var.num_cpus}"
  memory           = "${var.memory}"
  guest_id         = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type        = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = "${data.vsphere_network.default.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    # NOTE name is deprecated
    # https://www.terraform.io/docs/providers/vsphere/r/virtual_machine.html#name-1
    # name             = "${var.virtual_machine_name}.vmdk"
    label            = "disk0"
    size             = "${var.disk_size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
  }

  extra_config = {
    # FIXME base64 encoding did not work locally
    # guestinfo.coreos.config.encoding = "base64"
    # guestinfo.coreos.config.data     = "${base64encode(data.template_file.user_data.rendered)}"
    guestinfo.coreos.config.data     = "${data.template_file.user_data.rendered}"
  }

  provisioner "file" {
    source      = "ssl/fullchain.pem"
    destination = "/home/core/${var.domain_name}.crt.pem"

    connection {
      type        = "ssh"
      user        = "core"
      private_key = "${file(".ssh/id_rsa")}"
    }
  }

  provisioner "file" {
    source      = "ssl/privkey.pem"
    destination = "/home/core/${var.domain_name}.key.pem"

    connection {
      type        = "ssh"
      user        = "core"
      private_key = "${file(".ssh/id_rsa")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/certs",
      "sudo mv /home/core/${var.domain_name}.* /etc/certs/",
      "sudo chmod 600 -R /etc/certs",
    ]

    connection {
      type = "ssh"
      user = "core"
      private_key = "${file(".ssh/id_rsa")}"
    }
  }
}

output "ipv4_address" {
  value = "${vsphere_virtual_machine.default.default_ip_address}"
}
