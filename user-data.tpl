#cloud-config
# vim: set filetype=yaml :

ssh_authorized_keys:
  - "${ssh_authorized_key}"

  
coreos:
  units:
    - name: systemd-networkd.service
      command: stop

    # NOTE leaving as service name with eth0 as described in the docs, but the
    # actual name seems to be ens192
    - name: 00-eth0.network
      runtime: true
      content: |
        [Match]
        Name=ens192

        [Network]
        DNS=${network_dns}
        Address=${network_address}
        Gateway=${network_gateway}

    - name: down-interfaces.service
      content: |
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/ip link set ens192 down
        ExecStart=/usr/bin/ip addr flush dev ens192
      command: start

    - name: systemd-networkd.service
      command: restart


    # NOTE on using -e to set the notifications endpoints
    # https://github.com/docker/distribution/issues/625#issuecomment-308411450
    - name: docker-registry.service
      content: |
        [Unit]
        Description=Launch a local Docker registry
        Requires=docker.service
        After=docker.service

        [Service]
        ExecStartPre=-/usr/bin/docker kill %n
        ExecStartPre=-/usr/bin/docker rm -v %n
        ExecStart=/usr/bin/docker run \
          --name %n \
          -v /mnt/registry:/var/lib/registry \
          -v /etc/certs:/certs \
          -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
          -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/${domain_name}.crt.pem \
          -e REGISTRY_HTTP_TLS_KEY=/certs/${domain_name}.key.pem \
          -e REGISTRY_NOTIFICATIONS_ENDPOINTS=${notifications_endpoints} \
          -p 5000:5000 \
          -p 443:443 \
          registry:2
        ExecStop=/usr/bin/docker stop -t 3 %n
        Restart=on-failure
        RestartSec=5
      command: start
