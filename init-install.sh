#!/bin/bash

####
# curl -s http://rocklogic.at/tmp/stereum-setup-guided.sh | bash

stereum_version_tag="RELEASE"

dialog_backtitle="Stereum Node Installation - $stereum_version_tag"
dialog_overrides_title="Customize Setup"
dialog_overrides_text="Customize your node:"
dialog_overrides_default="default"

eth1_node=

# check for necessary packages for installing stereum
function check_dependencies() {
  echo "Checking dependencies (python3, dialog)..."
  apt install python3 python3-pip dialog -y -qq &>/dev/null
}

function check_privileges() {
  echo "Checking privileges..."
  if [[ $EUID -ne 0 && "$(ps -o comm= | sed -n '1p')" -ne "su" ]]; then
    clear
    echo "This script must be run as root or with sudo."
    exit 1
  fi
}

function install_stereum() {
  stereum_installer_file="/tmp/stereum-installer-$stereum_version_tag.run"

  wget -q -O "$stereum_installer_file" "https://stereum.net/downloads/init-setup-$stereum_version_tag.run"

  chmod +x "$stereum_installer_file"
  "$stereum_installer_file" \
    -e install_path="$install_path" \
    -e e2dc_network="$e2dc_network" \
    -e e2dc_client="$e2dc_client" \
    -e e2dc_override="$e2dc_override" \
    -e eth1_node="$eth1_node" \
    -e stereum_version_tag="$stereum_version_tag"\
    > "/var/log/stereum-installer.log" 2>&1

  rm "$stereum_installer_file"
}

function dialog_installation_successful() {
  dialog --backtitle "$dialog_backtitle" \
    --title "Successful" \
    --msgbox "Installation successful!\n\nRun the command 'stereum-control-center-cli' to configure your node." \
    9 40
  dialog --clear
  clear
}

function dialog_install_progress() {
  (
    echo "XXX"
    echo "Download and run install... (this might take a couple of minutes)"
    echo "XXX"
    echo "20"
    install_stereum

    echo "XXX"
    echo "Done!"
    echo "XXX"
    echo "100"
    sleep 1
  ) |
    dialog --backtitle "$dialog_backtitle" \
      --title "Installation Progress" \
      --gauge "Starting installation..." \
      8 40

  dialog --clear
}

function dialog_overrides_prysm() {
  e2dc_override=$(dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_overrides_title" \
    --menu "$dialog_overrides_text" 0 0 0 \
    "$dialog_overrides_default" "Default configuration (geth, beacon, validator, grafana, prometheus)" \
    "beacon-validator" "Beacon and validator only" \
    "geth-cache-2k" "Default configuration with geth cache 2000" \
    "time-mount" "Default configuration with forced time sync of containers with host os (linux only)" \
    3>&1 1>&2 2>&3)
}

function dialog_overrides_multiclient() {
  e2dc_override=$(dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_overrides_title" \
    --menu "$dialog_overrides_text" 0 0 0 \
    "$dialog_overrides_default" "Default configuration (geth, all beacons, slashers, monitoring)" \
    "limit-resources" "Default configuration with resource limits per container" \
    3>&1 1>&2 2>&3)
}

function dialog_overrides_lighthouse() {
  e2dc_override=$(dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_overrides_title" \
    --menu "$dialog_overrides_text" 0 0 0 \
    "$dialog_overrides_default" "Default configuration (geth, beacon, validator, grafana, prometheus)" \
    "no-geth" "Configuration without geth, using an external Ethereum 1 node (like infura.io)" \
    3>&1 1>&2 2>&3)
}

function dialog_overrides_lodestar() {
  # same as lighthouse
  dialog_overrides_lighthouse
}

function dialog_overrides_nimbus() {
  # same as lighthouse
  dialog_overrides_lighthouse
}

function dialog_overrides_teku() {
  # same as lighthouse
  dialog_overrides_lighthouse
}

function dialog_overrides_allbeacons() {
  # no overrides for allbeacons
  e2dc_override="$dialog_overrides_default"
}

function dialog_external_eth1() {
  eth1_node=$(dialog --backtitle "$dialog_backtitle" \
    --title "External Ethereum 1 node" \
    --inputbox "Please enter the url of the Ethereum 1 node:" \
    0 0 \
    "https://mainnet.infura.io:443/v3/put-your-infura-id-here" \
    3>&1 1>&2 2>&3)

  dialog --clear
}

function dialog_overrides() {
  dialog_overrides_$e2dc_client

  if [ "$e2dc_override" = "no-geth" ] || [ "$e2dc_override" = "beacon-validator" ]; then
    dialog_external_eth1
  fi
}

function dialog_network() {
  e2dc_network=$(dialog --backtitle "$dialog_backtitle" \
    --title "Network" \
    --menu "Please select the network you want to connect to:" 0 0 0 \
    "mainnet" "Mainnet" \
    "pyrmont" "Pyrmont testnet (old)" \
    "prater" "Prater testnet (new)" \
    3>&1 1>&2 2>&3)

  dialog --clear
}

function dialog_client() {
  e2dc_client=$(dialog --backtitle "$dialog_backtitle" \
    --title "Client setup" \
    --menu "Please choose the setup to install and configure:" 0 0 0 \
    "lighthouse" "Lighthouse by Sigma Prime" \
    "lodestar" "Lodestar by ChainSafe" \
    "multiclient" "Multiclient using Lighthouse, Prysm, Teku with Vouch, Dirk" \
    "nimbus" "Nimbus Eth2 by Status" \
    "prysm" "Prysm by Prysmatic Labs" \
    "teku" "Teku by ConsenSys" \
    "allbeacons" "All beacons: lighthouse, lodestar, nimbus, prysm, teku and no validators" \
    3>&1 1>&2 2>&3)

  dialog --clear
}

function dialog_path() {
  install_path=$(dialog --backtitle "$dialog_backtitle" \
    --title "Installation Path" \
    --inputbox "Please enter the path to use to install Stereum's Ethereum 2.0 node:" \
    0 0 \
    "/opt/stereum" \
    3>&1 1>&2 2>&3)

  dialog --clear
}

function dialog_welcome() {
  dialog --backtitle "$dialog_backtitle" \
    --title "Welcome!" \
    --yesno "Welcome to Stereum's Ethereum 2.0 node installer!\n\nYou are about to install an Ethereum 2.0 node on this host. This is a guided installation, we need some information to finish up your node for you!\n\nVisit https://stereum.net for more information!" \
    0 0
  choice=$?

  dialog --clear

  if [ $choice != 0 ]; then
    clear
    exit 1
  fi
}

check_privileges
check_dependencies
dialog_welcome
dialog_path
dialog_client
dialog_network
dialog_overrides
dialog_install_progress
dialog_installation_successful

# EOF

