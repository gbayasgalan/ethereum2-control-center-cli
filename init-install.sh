#!/bin/bash

####
# curl -s http://rocklogic.at/tmp/stereum-setup-guided.sh | bash

dialog_title="Stereum Node Installation"

# check for necessary packages for installing stereum
function check_dependencies() {
  apt install python3 python3-pip dialog -y -qq &> /dev/null
}

function check_priviliges() {
  if [[ $EUID -ne 0 ]]; then
    clear
    echo "This script must be run as root or with sudo."
    exit 1
  fi
}

function install_config() {
  mkdir -p /etc/stereum

  echo "e2dc_install_path: $install_path/ethereum2-docker-compose
stereum_user: stereum
network: $e2dc_network
setup: $e2dc_client

# mapping table (key, value) with network name as key and branch name as value
networks:
  pyrmont: master
  mainnet: mainnet

setups:
  lighthouse:
    services:
      - geth
      - beacon
      - validator
      - prometheus
      - grafana
    validator_services:
      - validator
    compose_path: lighthouse-only/docker-compose.yaml
    create_account: lighthouse-only/create-account.yaml
  prysm:
    services:
      - geth
      - beacon
      - slasher
      - validator
      - prometheus
      - grafana
    validator_services:
      - validator
    compose_path: prysm-only/docker-compose.yaml
    create_account: prysm-only/create-account.yaml
  multiclient:
    services:
      - geth
      - prysm_beacon
      - prysm_beacon_slasher
      - lighthouse_beacon
      - teku_beacon
      - dirk
      - vouch
      - prysm_slasher
      - grafana
      - prometheus
    validator_services:
      - dirk
      - vouch
    compose_path: multiclient-vouch-dirk/docker-compose.yaml

# docker settings
docker_address_pool_base: 172.80.0.0/12
docker_address_pool_size: 24
" > /etc/stereum/ethereum2.yaml

  chmod +r /etc/stereum/ethereum2.yaml
}

function install_stereum() {
  wget -q -O /tmp/stereum-installer.run http://rocklogic.at/tmp/init-setup.run

  chmod +x /tmp/stereum-installer.run
  /tmp/stereum-installer.run > "/var/log/stereum-installer.log" 2>&1

  rm /tmp/stereum-installer.run
}

function dialog_installation_successful() {
    dialog --title "$dialog_title" \
      --msgbox "Installation successful!" \
      8 40
    dialog --clear
    clear
}

function dialog_install_progress() {
  (
    echo "XXX"; echo "Configure..."; echo "XXX"
    echo "10"; install_config

    echo "XXX"; echo "Download and run install... (this might take a couple of minutes)"; echo "XXX"
    echo "20"; install_stereum

    echo "XXX"; echo "Done!"; echo "XXX"
    echo "100"; sleep 1
  ) |
  dialog --title "$dialog_title" \
    --gauge "Starting installation..." \
    8 40

  dialog --clear
}

function dialog_network() {
  e2dc_network=$(dialog --title "$dialog_title" \
    --menu "Please select the network you want to connect to:" 0 0 0 \
    "mainnet" "Mainnet" \
    "pyrmont" "Pyrmont testnet" \
    3>&1 1>&2 2>&3)

  dialog --clear
}

function dialog_client() {
  e2dc_client=$(dialog --title "$dialog_title" \
    --menu "Please choose the setup to install and configure:" 0 0 0 \
    "lighthouse" "Lighthouse by Sigma Prime" \
    "lodestar" "Lodestar by ChainSafe" \
    "multiclient" "Multiclient using Lighthouse, Prysm, Teku with Vouch, Dirk" \
    "nimbus" "Nimbus Eth2 by Status" \
    "prysm" "Prysm by Prysmatic Labs" \
    "teku" "Teku by ConsenSys" \
     3>&1 1>&2 2>&3)

  dialog --clear
}

function dialog_path() {
  install_path=$(dialog --title "$dialog_title" \
    --inputbox "Please enter the path to use to install Stereum's Ethereum 2.0 node:" \
    0 0 \
    "/opt/stereum" \
    3>&1 1>&2 2>&3)

  dialog --clear
}

function dialog_welcome() {
  dialog --title "$dialog_title" \
    --yesno "Welcome to Stereum's Ethereum 2.0 node installer!\n\nYou are about to install an Ethereum 2.0 node on this host. This is a guided installation, we need some information to finish up your node for you!" \
    0 0
  choice=$?

  dialog --clear

  if [ $choice != 0 ]; then
    clear
    exit 1
  fi
}

check_priviliges
check_dependencies
dialog_welcome
dialog_path
dialog_client
dialog_network
dialog_install_progress
dialog_installation_successful

# EOF