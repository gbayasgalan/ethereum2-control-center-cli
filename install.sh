#!/bin/bash

installer_version="0.0.1-alpha"
stereum_install_path="/opt/stereum"
ccc_install_path="$stereum_install_path/control-center-cli"
e2a_install_path="$stereum_install_path/ansible"
stereum_config_path="/etc/stereum"
stereum_config_file="$stereum_config_path/ethereum2.yaml"

function welcome_ccc() {
    dialog --msgbox "Installation successful, go to $ccc_install_path and run\n'sudo ./stereum-control-center-cli.sh'" 0 0
    dialog --clear
    clear
}

function install_ccc() {
  # install apps to /opt
  mkdir -p "$stereum_install_path"

  git clone https://github.com/stereum-dev/ethereum2-control-center-cli.git "$ccc_install_path" -q
  git clone https://github.com/stereum-dev/ethereum2-ansible.git "$e2a_install_path" -q

  current_user=$(who am i | awk '{print $1}')

  chown -R "$current_user":"$current_user" "$stereum_install_path"

  # install config to /etc
  mkdir -p "$stereum_config_path"

  echo "ccc-path: $ccc_install_path
e2a-path: $e2a_install_path
installer-version: $installer_version
installation-date: $(date +%s)" > $stereum_config_file
}

function check_dependency() {
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $1 | grep "install ok installed")
  if [ "" = "$PKG_OK" ]; then
    apt install $1 -qq > /dev/null
  fi
}

function check_dependencies() {
  check_dependency git
  check_dependency python
}

function check_privileges() {
  # check for sudo/root first, make sure to have privileges to install stuff and configure
  if [[ $EUID -ne 0 ]]; then
    clear
    echo "This script must be run as root or with sudo."
    exit 1
  fi
}

# check for existing config file - if any found, abort because of already existing installation
function check_installed() {
  if [ -f "$stereum_config_file" ]
  then
    clear
    echo "Fatal: Installation found: $stereum_config_path"
    exit 1
  fi
}

function confirm_install() {
  dialog --yesno "This system wasn't altered yet.\nYou are about to install stereum's control centerl cli. Please confirm to install:\n1) git\n2) python\n3) Stereum's control center cli\n4) Stereum's ansible suite\n\nInstall paths:\n$ccc_install_path\n$e2a_install_path" 0 0
  choice=$?

  if [ $choice != 0 ]; then
    clear
    exit 1
  else
    check_installed
    check_privileges
    check_dependencies
    install_ccc
    welcome_ccc
  fi
}

confirm_install

#EOF