data "template_file" "notifications_endpoints" {
  template = "${file("notifications_endpoints.tpl")}"

  vars {
    notifications_endpoints_name     = "${var.notifications_endpoints_name}"
    notifications_endpoints_disabled = "${var.notifications_endpoints_disabled}"
    notifications_endpoints_url      = "${var.notifications_endpoints_url}"
  }
}
