- name: ${notifications_endpoints_name}
  disabled: ${notifications_endpoints_disabled}
  url: ${notifications_endpoints_url}
  timeout: 500
  threshold: 5
  backoff: 1000
  ignoredmediatypes:
    - application/octet-stream
