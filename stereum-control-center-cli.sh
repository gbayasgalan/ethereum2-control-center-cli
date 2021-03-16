#!/bin/bash

# check for sudo/root first, make sure to have privileges to install stuff and configure
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo."
   exit 1
fi

dialog_title="Stereum Control Center"
stereum_config_file_path=/etc/stereum/ethereum2.yaml

function dialog_import_wallet() {
  choice_launchpad_wallet_path=$(dialog --title "$dialog_title" \
    --inputbox "Please enter the directory of the validator_keys\n(e. g. /tmp/validator_keys):" 9 60 "" \
    3>&1 1>&2 2>&3)

  choice_launchpad_wallet_password=$(dialog --title "$dialog_title" \
    --inputbox "Please enter the password of the validator_keys:" 9 60 "" \
    3>&1 1>&2 2>&3)

  ansible-playbook \
    -e validator_keys_path="$choice_launchpad_wallet_path" \
    -e validator_password="$choice_launchpad_wallet_password" \
    -v \
    "${e2a_install_path}/import-validator-accounts.yaml" \
    > /dev/null 2>&1

  dialog --title "$dialog_title" \
    --msgbox "Import done, necessary services restarted." 5 50

  dialog --clear

  dialog_main
}

function dialog_update() {
  choice_update_version_tag=$(dialog --title "$dialog_title" \
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
  dialog --title "$dialog_title" \
    --gauge "Starting update..." \
    8 40

  dialog --title "$dialog_title" \
    --msgbox "Update done, services restarted!" 5 50

  dialog --clear

  dialog_main
}

function dialog_restart_host() {
  dialog --title "$dialog_title" \
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
  dialog --title "$dialog_title" \
    --gauge "Restarting services..." \
    8 40

  dialog --title "$dialog_title" \
    --msgbox "Restarting done, services restarted." 5 50

  dialog --clear

  dialog_main
}

function dialog_port_list() {
  dialog --title "$dialog_title" \
    --msgbox "Feature not ready yet." 5 50

  dialog --clear

  dialog_main
}

function dialog_main() {
  choice_main=$(dialog --title "$dialog_title - Main Menu" \
    --menu "" 0 0 0 \
    "import-wallet" "Import a wallet of launchpad.ethereum.org" \
    "update" "Update your OS and Stereum Node" \
    "restart-host" "Restart the server" \
    "restart-services" "Restart certain services" \
    "port-list" "List used ports" \
    "quit" "Quit the Stereum Control Center" \
     3>&1 1>&2 2>&3)

  dialog --clear

  if [ "$choice_main" == "import-wallet" ]; then
    dialog_import_wallet
  elif [ "$choice_main" == "update" ]; then
    dialog_update
  elif [ "$choice_main" == "restart-host" ]; then
    dialog_restart_host
  elif [ "$choice_main" == "restart-services" ]; then
    dialog_restart_services
  elif [ "$choice_main" == "port-list" ]; then
    dialog_port_list
  elif [ "$choice_main" == "quit" ]; then
    clear
    exit 0
  fi
}

function check_config() {
  if [[ -f "$stereum_config_file_path" ]]; then
    echo "Found config $stereum_config_file_path"

    script_relative_path=$(dirname "$BASH_SOURCE")

    source "${script_relative_path}/helper/yaml.sh"
    create_variables "$stereum_config_file_path"
  else
    echo "No config found at $stereum_config_file_path"
    exit 1
  fi
}

check_config
dialog_main

#EOF