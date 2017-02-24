#!/bin/bash

# Set up latest ansible
apt-get install -y software-properties-common
apt-add-repository ppa:ansible/ansible
apt-get update
apt-get install -y ansible
curl "https://bootstrap.pypa.io/get-pip.py" -o - | python
# set up pywinrm module to enable ansilbe to remote powershell communication
pip install "pywinrm>=0.1.1"


