data "template_file" "user_data" {
  template = "${file("user-data.tpl")}"

  vars {
    network_dns     = "${var.network_dns}"
    network_address = "${var.network_address}"
    network_gateway = "${var.network_gateway}"

    ssh_authorized_key = "${file("./.ssh/id_rsa.pub")}"

    domain_name = "${var.domain_name}"

    // NOTE must jsonencode or the \n in the rendered notifications_endpoints
    // file breaks the cloud-config 
    notifications_endpoints = "${jsonencode(replace(data.template_file.notifications_endpoints.rendered, "/(\n)$/", ""))}"
  }
}
