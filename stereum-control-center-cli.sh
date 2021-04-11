#!/bin/bash

# check for sudo/root first, make sure to have privileges to install stuff and configure
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo."
   exit 1
fi

dialog_title="Stereum Control Center"
stereum_config_file_path=/etc/stereum/ethereum2.yaml

function dialog_import_wallet() {
  if [ "$setup" == "multiclient" ]; then
  choice_validator_number=$(dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --inputbox "Please enter the number of the validator_keys:" 9 60 "" \
    3>&1 1>&2 2>&3)

  choice_validator_mnemonic=$(dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --inputbox "Please enter the mnemonic of the validator_keys:" 9 60 "" \
    3>&1 1>&2 2>&3)

  ansible-playbook \
    -e validator_number="$choice_validator_number" \
    -e validator_mnemonic="$choice_validator_mnemonic" \
    -v \
    "${e2a_install_path}/import-validator-accounts.yaml" \
    > /dev/null 2>&1

  else
	
  choice_launchpad_wallet_path=$(dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --inputbox "Please enter the directory of the validator_keys\n(e. g. /tmp/validator_keys):" 9 60 "" \
    3>&1 1>&2 2>&3)

  choice_launchpad_wallet_password=$(dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --inputbox "Please enter the password of the validator_keys:" 9 60 "" \
    3>&1 1>&2 2>&3)

  dialog --backtitle "$dialog_backtitle" \
    --infobox "Importing keys..." 3 19

  ansible-playbook \
    -e validator_keys_path="$choice_launchpad_wallet_path" \
    -e validator_password="$choice_launchpad_wallet_password" \
    -v \
    "${e2a_install_path}/import-validator-accounts.yaml" \
    > /dev/null 2>&1
  fi

  dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --msgbox "Import done, please see /var/log/anisble.log or grafana for details!" 6 50

  dialog --clear

  dialog_main
}

function dialog_update() {
  choice_update_version_tag=$(dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --inputbox "What version do you want to use?" 9 60 "" \
    3>&1 1>&2 2>&3)

  (
    echo "XXX"; echo "Downloading new version..."; echo "XXX"
    echo "10"; ansible-playbook -e stereum_version_tag="$choice_update_version_tag" -v "${e2a_install_path}/stop-and-update.yaml" > /dev/null 2>&1

    echo "XXX"; echo "Configuring..."; echo "XXX"
    echo "60"; ansible-playbook -v "${e2a_install_path}/finish-update.yaml" > /dev/null 2>&1

    echo "XXX"; echo "Done!"; echo "XXX"
    echo "100"; sleep 1
  ) |
  dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --gauge "Starting update..." \
    8 40

  dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --msgbox "Update done, services restarted!" 5 50

  dialog --clear

  dialog_main
}

function dialog_graffiti() {
  choice_graffiti=$(dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --inputbox "Please enter new graffiti:" 9 60 "" \
    3>&1 1>&2 2>&3)

  dialog --backtitle "$dialog_backtitle" \
    --infobox "Setting graffiti..." 0 0

  ansible-playbook \
    -e e2dc_graffiti_updated="$choice_graffiti" \
    -v \
    "${e2a_install_path}/set-graffiti.yaml" \
    > /dev/null 2>&1

  dialog_main
}

function dialog_api_bind_addr() {
  choice_api_bind_addr=$(dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --inputbox "Please enter new IP to bind api listening:" 9 60 "" \
    3>&1 1>&2 2>&3)

  dialog --backtitle "$dialog_backtitle" \
    --infobox "Setting api bind address..." 0 0

  ansible-playbook \
    -e e2dc_api_bind_address_updated="$choice_api_bind_addr" \
    -v \
    "${e2a_install_path}/set-api-bind-address.yaml" \
    > /dev/null 2>&1

  dialog_main
}

function dialog_restart_host() {
  dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --yesno "Are you sure to restart the host?" \
    0 0
  choice=$?

  if [ $choice != 0 ]; then
    dialog --clear
    dialog_main
  else
    clear
    reboot
  fi
}

function dialog_restart_services() {
  (
    echo "XXX"; echo "Restarting services..."; echo "XXX"
    echo "10"; ansible-playbook -v "${e2a_install_path}/restart-services.yaml" > /dev/null 2>&1

    echo "XXX"; echo "Done!"; echo "XXX"
    echo "100"; sleep 1
  ) |
  dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --gauge "Restarting services..." \
    8 40

  dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --msgbox "Restarting done, services restarted." 5 50

  dialog --clear

  dialog_main
}

function dialog_geth_prune() {
  dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --yesno "While geth is in the process of pruning there is no way your validators can create blocks. The process might take several hours depending on your hardware.\n\nDo you want to continue?" \
    0 0
  choice=$?

  if [ $choice != 0 ]; then
    dialog --clear
    dialog_main
  else
    ansible-playbook -v "${e2a_install_path}/geth-prune.yaml" > /dev/null 2>&1 &

    dialog --backtitle "$dialog_backtitle" \
      --title "$dialog_title" \
      --msgbox "Geth stoppend and pruning started.\n\nGeth will start automatically after pruning is done!" 0 0

    dialog --clear
    dialog_main
  fi
}

function dialog_port_list() {
  dialog --backtitle "$dialog_backtitle" \
    --infobox "Reading services and ports..." 3 34

  ansible-playbook -v "${e2a_install_path}/list-ports.yaml" > /dev/null 2>&1

  dialog --backtitle "$dialog_backtitle" \
    --textbox "${e2dc_install_path}/open-ports-list.txt" 0 0

  dialog --clear

  dialog_main
}

function dialog_exit_validator() {
  if [[ "$setup" == "lodestar" || "$setup" == "prysm" ]]; then
    choice_validator_pubkey=$(dialog --backtitle "$dialog_backtitle" \
      --title "$dialog_title" \
      --inputbox "Please enter validator's pubkey ( e. g: 0x1234abcd..... ):" 9 60 "" \
      3>&1 1>&2 2>&3)

    ansible-playbook \
      -e validator_pubkey="$choice_validator_pubkey" \
      -v \
      "${e2a_install_path}/exit-validator-accounts.yaml" \
      > /dev/null 2>&1

  else

    choice_validator_keystore_file=$(dialog --backtitle "$dialog_backtitle" \
      --title "$dialog_title" \
      --inputbox "Please enter the name of keystore file (e.g: keystore-m_12345_1234_0_0_0-1234567890.json ) :" 9 60 "" \
      3>&1 1>&2 2>&3)

    choice_validator_password=$(dialog --backtitle "$dialog_backtitle" \
      --title "$dialog_title" \
      --inputbox "Please enter account password:" 9 60 "" \
      3>&1 1>&2 2>&3)

    dialog --backtitle "$dialog_backtitle" \
      --infobox "exiting validator account..." 0 0

    ansible-playbook \
      -e validator_keystore="$choice_validator_keystore_file" \
      -e validator_password="$choice_validator_password" \
      -v \
      "${e2a_install_path}/exit-validator-accounts.yaml" \
      > /dev/null 2>&1
  fi

  dialog_main
}

function dialog_main() {
  choice_main=$(dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title - Main Menu" \
    --menu "" 0 0 0 \
    "import-wallet" "Import a wallet of launchpad.ethereum.org" \
    "update" "Update your OS and Stereum Node" \
    "graffiti" "Set graffiti for staking" \
    "api-bind-addr" "Bind address for apis (default: 127.0.0.1)" \
    "restart-host" "Restart the server" \
    "restart-services" "Restart certain services" \
    "geth-prune" "Prune geth to reallocate disk space" \
    "port-list" "List used ports" \
    "exit-account" "Voluntary exit of validator" \
    "quit" "Quit the Stereum Control Center" \
     3>&1 1>&2 2>&3)

  dialog --clear

  if [ "$choice_main" == "import-wallet" ]; then
    dialog_import_wallet
  elif [ "$choice_main" == "update" ]; then
    dialog_update
  elif [ "$choice_main" == "graffiti" ]; then
    dialog_graffiti
  elif [ "$choice_main" == "api-bind-addr" ]; then
    dialog_api_bind_addr
  elif [ "$choice_main" == "restart-host" ]; then
    dialog_restart_host
  elif [ "$choice_main" == "restart-services" ]; then
    dialog_restart_services
  elif [ "$choice_main" == "geth-prune" ]; then
    dialog_geth_prune
  elif [ "$choice_main" == "port-list" ]; then
    dialog_port_list
  elif [ "$choice_main" == "exit-account" ]; then
    dialog_exit_validator  
  elif [ "$choice_main" == "quit" ]; then
    clear
    exit 0
  fi
}

function check_config() {
  if [[ -f "$stereum_config_file_path" ]]; then
    echo "Found config $stereum_config_file_path"

    script_relative_path="$(dirname "$(readlink -f "$0")")"

    source "${script_relative_path}/helper/yaml.sh"
    create_variables "$stereum_config_file_path"

    stereum_version_tag=$(git -C "$e2ccc_install_path" describe --tags)
    dialog_backtitle="Stereum Node Control Center - $stereum_version_tag"
  else
    echo "No config found at $stereum_config_file_path"
    exit 1
  fi
}

check_config
dialog_main

#EOF
