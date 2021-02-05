#!/bin/bash

# check for sudo/root first, make sure to have priviliges to install stuff and configure
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo."
   exit 1
fi

function install_edc {
  git clone https://github.com/stereum-dev/ethereum2-docker-compose.git "$choice_install_path"

  if [[ "$choice_network" == "mainnet" ]]
  then
    git -C "$choice_install_path" checkout mainnet
  fi
}

function confirm_install {
  dialog --yesno "Installing \"$choice_client\" with settings for network \"$choice_network\" to directory \"$choice_install_path\", is this correct?" 0 0

  dialog --clear
  clear

  choice=$?

  if [ $choice = 0 ]
  then
    install_edc
  fi
}

function edc_install() {
  choice_client=$(dialog --menu "Please choose the setup to install and configure:" 0 0 0 \
    "lighthouse-only" "Lighthouse by Sigma Prime" "lodestar-only" "Lodestar by ChainSafe" "multiclient" "Multiclient using Lighthouse, Prysm, Teku with Vouch, Dirk" "nimbus-only" "Nimbus Eth2 by Status" "prysm-only" "Prysm by Prysmatic Labs" "teku-only" "Teku by ConsenSys" 3>&1 1>&2 2>&3)
  dialog --clear

  choice_network=$(dialog --menu "Please select the network you want to connect to:" 0 0 0 \
    "mainnet" "Mainnet for real Ether" "pyrmont" "Pyrmont Testnet for Goerli Ether" 3>&1 1>&2 2>&3)
  dialog --clear

  clear

  confirm_install
}

function main_menu() {
  choice_main_menu=$(dialog --menu "Stereum's control center v0.0.1-alpha\n\nPlease select" 0 0 0 \
    "install" "Install ethereum2-docker-compose" \
    "start" "Start services" \
    "stop" "Stop services" \
    "import" "Import launchpad validator keys" \
    3>&1 1>&2 2>&3)
  dialog --clear

  clear


}

function new_install_path() {
  choice_install_path=`dialog --inputbox "Please state \nthe installation path (in full):" 0 0 "/opt/ethereum2-docker-compose" \
    3>&1 1>&2 2>&3`
  dialog --clear

  if [ -z "$choice_install_path" ]
  then
    clear
    exit 1
  fi

  if [ -d "$choice_install_path" ]
  then
    if [ -d "$choice_install_path/.install-config" ]
    then
      # this is an already installed ethereum2-docker-compose
      dialog --msgbox "Found installation!" 0 0
      dialog --clear
    else
      dialog --yesno "This directory exists already and it doesn't look like an ethereum2-docker-compose install. Any data in this directory might be overwritten. Are you sure to continue?" 0 0
      choice=$?

      if [ $choice != 0 ]
      then
        clear
        exit 1
      else
        edc_install
      fi
    fi
  else
    edc_install
  fi
}

main_menu

#EOF