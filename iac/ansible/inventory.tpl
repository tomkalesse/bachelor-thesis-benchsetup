[manager]
${manager_ip}

[odc_sut]
${odc_sut_ip}

[odc_client]
${odc_client_ip}

[rasdaman_sut]
${rasdaman_sut_ip}

[rasdaman_client]
${rasdaman_client_ip}

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
