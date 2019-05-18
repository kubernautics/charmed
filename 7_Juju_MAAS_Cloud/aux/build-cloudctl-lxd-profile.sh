cat <<EOF >/tmp/lxd_profile_cloudctl.yaml
config:
  user.network-config: |
    version: 2
    ethernets:
      eth0:
        dhcp4: false
        dhcp6: false
        addresses: [ 10.10.0.3/24 ]
        gateway4: 10.10.0.1
        nameservers:
          addresses: [ 10.10.0.10 ]
          search: [ maas ]
  user.user-data: |
    #cloud-config
    package_upgrade: true
    packages:
      - jq
      - vim
      - tree
      - tmux
      - byobu
      - lnav
      - snapd
      - maas-cli
      - squashfuse
      - libvirt-bin
      - python-pip
    ssh_import_id: ${ccio_SSH_UNAME}
    users:
      - name: ubuntu
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_import_id: ${ccio_SSH_UNAME}
      - name: ${ccio_SSH_UNAME}
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_import_id: ${ccio_SSH_UNAME}
    write_files:
      - content: |
          clouds:
            maasctl:
              type: maas
              auth-types: [oauth1]
              endpoint: http://10.10.0.10:5240/MAAS
        path: /home/ubuntu/.juju/maasctl.yaml
      - content: |
          credentials:
            maasctl:
              admin:
                content:
                  auth-type: oauth1
                  maas-oauth: ${maasctl_api_key}
                models:
                  default: admin
                  controller: admin
        path: /home/ubuntu/.juju/credentials-maasctl.yaml
    runcmd:
      - [apt-get, autoremove, "-y"]
      - [cp, "-f", "/etc/skel/.bashrc", "/root/.bashrc"]
      - [cp, "-f", "/etc/skel/.bashrc", "/home/ubuntu/.bashrc"]
      - [cp, "-f", "/etc/skel/.bashrc", "/home/${ccio_SSH_UNAME}/.bashrc"]
      - [apt-get, autoremove, "-y"]
      - [pip, install, python-openstackclient]
      - [snap, install, juju, "--classic"]
      - [su, -l, ubuntu, /bin/bash, -c, "ssh-keygen -f ~/.ssh/id_rsa -N ''"]
      - [su, -l, ubuntu, /bin/bash, -c, "ssh-import-id", "${ccio_SSH_SERVICE}:${ccio_SSH_UNAME}"]
      - [su, -l, "${ccio_SSH_UNAME}", /bin/bash, -c, "ssh-import-id", "${ccio_SSH_SERVICE}:${ccio_SSH_UNAME}"]
      - [wget, "-O", "/usr/bin/login-maas-cli", "https://raw.githubusercontent.com/containercraft/mini-stack/master/5_MAAS-Rack_And_Region_Ctl-On-Open_vSwitch/aux/login-maas-cli"]
      - [chmod, "+x", "/usr/bin/login-maas-cli"]
      - [virsh, net-destroy, default]
      - [virsh, net-undefine, default]
      - [update-alternatives, "--set", "editor", "/usr/bin/vim.basic"]
      - [chown, "-R", "ubuntu:ubuntu", "/home/ubuntu"]
      - [su, "-l", ubuntu, "/bin/bash", "-c", "byobu-enable"]
      - [su, "-l", "${ccio_SSH_UNAME}", "/bin/bash", "-c", "byobu-enable"]
description: ccio mini-stack maasctl container profile
devices:
  eth0:
    name: eth0
    nictype: macvlan
    parent: lan
    type: nic
  root:
    path: /
    pool: default
    type: disk
name: cloudctl container profile
EOF

[[ $(lxc profile list | grep cloudctl ; echo $?) == 0 ]] || lxc profile create cloudctl
lxc profile edit cloudctl < <(sed "s/maasctl_api_key/${maasctl_api_key}/g" /tmp/lxd_profile_cloudctl.yaml)
