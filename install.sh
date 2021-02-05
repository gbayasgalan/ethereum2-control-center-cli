#!/bin/bash

installer_version="0.0.1-alpha"
stereum_install_path="/opt/stereum"
ccc_install_path="$stereum_install_path/control-center-cli"
e2a_install_path="$stereum_install_path/ansible"
e2dc_install_path="$stereum_install_path/node"
stereum_config_path="/etc/stereum"
stereum_config_file="$stereum_config_path/ethereum2.yaml"

dialog_title="Stereum Node Installation"

function welcome_ccc() {
    dialog --title "$dialog_title" \
      --msgbox "Installation successful, go to $ccc_install_path and run:\n'./stereum-control-center-cli.sh'" \
      8 40
    dialog --clear
    clear
}

function prepare_install_structure() {
  # install apps to /opt
  mkdir -p "$stereum_install_path"
}

function install_ccc() {
  git clone https://github.com/stereum-dev/ethereum2-control-center-cli.git "$ccc_install_path" -q
}

function install_e2a() {
  git clone https://github.com/stereum-dev/ethereum2-ansible.git "$e2a_install_path" -q
}

function install_e2dc() {
  git clone https://github.com/stereum-dev/ethereum2-docker-compose.git "$e2dc_install_path" -q

  if [[ "$e2dc_network" == "mainnet" ]]
  then
    git -C "$e2dc_install_path" checkout mainnet
  fi

  cp "$e2dc_install_path/compose-examples/$e2dc_client/docker-compose.yaml" "$e2dc_install_path/docker-compose.yaml"
}

function finish_install_structure() {
  current_user=$(who am i | awk '{print $1}')

  chown -R "$current_user":"$current_user" "$stereum_install_path"

  # install config to /etc
  mkdir -p "$stereum_config_path"

  echo "ccc-path: $ccc_install_path
e2a-path: $e2a_install_path
e2dc:
  path: $e2dc_install_path
  network: $e2dc_network
  client: $e2dc_client
installer-version: $installer_version
installation-date: $(date +%s)" > $stereum_config_file
}

function check_dependency() {
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $1 | grep "install ok installed")
  if [ "" = "$PKG_OK" ]; then
    apt install $1 -qq &> /dev/null
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

function stereum_install() {
  (
    echo "XXX"; echo "Check for previous installations"; echo "XXX"
    echo "10"; check_installed

    echo "XXX"; echo "Check for necessary privileges"; echo "XXX"
    echo "20"; check_privileges

    echo "XXX"; echo "Check for necessary software packages"; echo "XXX"
    echo "30"; check_dependencies

    echo "XXX"; echo "Prepare for installation"; echo "XXX"
    echo "35"; prepare_install_structure

    echo "XXX"; echo "Installing control center cli"; echo "XXX"
    echo "40"; install_ccc

    echo "XXX"; echo "Installing ansible suite"; echo "XXX"
    echo "50"; install_e2a

    echo "XXX"; echo "Installing node setup"; echo "XXX"
    echo "70"; install_e2dc

    echo "XXX"; echo "Finish structure and configuration"; echo "XXX"
    echo "90"; finish_install_structure

    echo "XXX"; echo "Done!"; echo "XXX"
    echo "100"; sleep 1
  ) |
  dialog --title "$dialog_title" \
    --gauge "Starting installation..." \
    8 40

  dialog --clear

  # at this point the script is done installing, show welcome screen
  welcome_ccc
}

function e2dc_choices() {
  e2dc_client=$(dialog --title "$dialog_title" \
    --menu "Please choose the setup to install and configure:" 0 0 0 \
    "lighthouse-only" "Lighthouse by Sigma Prime" \
    "lodestar-only" "Lodestar by ChainSafe" \
    "multiclient-vouch-dirk" "Multiclient using Lighthouse, Prysm, Teku with Vouch, Dirk" \
    "nimbus-only" "Nimbus Eth2 by Status" \
    "prysm-only" "Prysm by Prysmatic Labs" \
    "teku-only" "Teku by ConsenSys" \
     3>&1 1>&2 2>&3)
  dialog --clear

  e2dc_network=$(dialog --title "$dialog_title" \
    --menu "Please select the network you want to connect to:" 0 0 0 \
    "mainnet" "Mainnet for real Ether" \
    "pyrmont" "Pyrmont Testnet for Goerli Ether" \
    3>&1 1>&2 2>&3)
  dialog --clear

  clear

  stereum_install
}


function confirm_install() {
  dialog --title "$dialog_title" \
    --yesno "You are about to install an Ethereum 2.0 node. Please confirm to install:\n1) git\n2) python\n3) stereum control center cli\n4) stereum ansible suite\n5) stereum node setup\n\nInstall paths:\n$ccc_install_path\n$e2a_install_path\n$e2dc_install_path" \
    0 0
  choice=$?

  if [ $choice != 0 ]; then
    clear
    exit 1
  else
    e2dc_choices
  fi
}

confirm_install

#EOF