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

  if [ $choice_import_config != 0 ]; then
    "$stereum_installer_file" \
      -e install_path="$install_path" \
      -e network="$e2dc_network" \
      -e setup="$e2dc_client" \
      -e setup_override="$e2dc_override" \
      -e "{ \"connectivity\": { \"eth1_nodes\": [\"$eth1_node\"]}, \"update\": { \"lane\": \"$auto_update_lane\", \"unattended\": { \"check\": $auto_update_check_updates, \"install\": $auto_update_install_updates } } }" \
      -e stereum_version_tag="$stereum_version_tag" \
      > "/var/log/stereum-installer.log" 2>&1

  elif [ $choice_import_config == 0 ]; then
    apt-get install unzip -y
    unzip -o "$exported_config_path" -d /tmp
    echo "$exported_config_password" | gpg -d --output /tmp/exported-config/ethereum2.yaml --batch --yes --passphrase-fd 0 /tmp/exported-config/exported-config.gpg
    chmod -R 755 /tmp/exported-config

    "$stereum_installer_file" \
      -e install_path="$install_path" \
      -e network="$(grep 'network:' /tmp/exported-config/ethereum2.yaml | sed 's/^.*: //')" \
      -e setup="$(grep 'setup:' /tmp/exported-config/ethereum2.yaml | sed 's/^.*: //')" \
      -e setup_override="$(grep 'setup_override:' /tmp/exported-config/ethereum2.yaml | sed 's/^.*: //')" \
      -e "{ \"connectivity\": { \"eth1_nodes\": [\"$eth1_node\"]}, \"update\": { \"lane\": \"$auto_update_lane\", \"unattended\": { \"check\": $auto_update_check_updates, \"install\": $auto_update_install_updates } } }" \
      -e stereum_version_tag="$(grep 'stereum_version_tag:' /tmp/exported-config/ethereum2.yaml | sed 's/^.*: //')" \
      > "/var/log/stereum-installer.log" 2>&1
  fi

  rm "$stereum_installer_file"

  if [ $choice_import_validator != 0 ]; then
    rm -rf /tmp/exported-config

  elif [ $choice_import_validator == 0 ]; then
    importing_validator_number="$(ls -lR /tmp/exported-config/keystore-*.json | wc -l)"
  fi
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

function dialog_auto_updates() {
  dialog --backtitle "$dialog_backtitle" \
    --title "Unattended Automized Updates" \
    --yesno "Do you want to install updates automatically?" \
    0 0
  choice=$?

  if [ $choice == 0 ]; then
    auto_update_check_updates="true"
    auto_update_install_updates="true"

    auto_update_lane=$(dialog --backtitle "$dialog_backtitle" \
      --title "Auto Updates" \
      --menu "Please choose the lane you want to receive updates of:" 0 0 0 \
        "stable" "Install only stable updates (highly recommended!)" \
        "rc" "Install release candidates (this can break your setup!)" \
      3>&1 1>&2 2>&3)
  else
    auto_update_check_updates="false"
    auto_update_install_updates="false"
    auto_update_lane="stable"
  fi
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

function dialog_import_config() {
  dialog --backtitle "$dialog_backtitle" \
    --title "Import Configuration" \
    --yesno "Do you want to import saved Configuration" \
    0 0
  choice_import_config=$?

  if [ $choice_import_config == 0 ]; then
    dialog --backtitle "$dialog_backtitle" \
      --title "Import Configuration" \
      --yesno "Do you want to import with validators" \
      0 0
    choice_import_validator=$?

    exported_config_path=$(dialog --backtitle "$dialog_backtitle" \
      --title "Import Configuration" \
      --inputbox "Please enter the PATH to the importing file (e. g: /tmp/exported-config.zip)" \
      0 0 \
      "/tmp/exported-config" \
      3>&1 1>&2 2>&3)

    exported_config_password=$(dialog --backtitle "$dialog_backtitle" \
      --title "Import Configuration" \
      --inputbox "Please enter the PASSWORD for exported configuration File ( The password used to export configuration )" \
      0 0 \
      3>&1 1>&2 2>&3)

    if [ $choice_import_validator == 0 ]; then
      exported_validator_password=$(dialog --backtitle "$dialog_backtitle" \
        --title "" \
        --inputbox "Please enter the PASSWORD for exported Validators" \
        0 0 \
        3>&1 1>&2 2>&3)
    fi
  fi

  dialog --clear
}

function dialog_import_validator() {
  if [ "$(grep 'setup:' /tmp/exported-config/ethereum2.yaml | sed 's/^.*: //')" == "multiclient" ]; then
    choice_validator_mnemonic=$(dialog --backtitle "$dialog_backtitle" \
    --title "$dialog_title" \
    --inputbox "Please enter the mnemonic of the importing 'Validator Keys':" 9 60 "" \
    3>&1 1>&2 2>&3)

    dialog --backtitle "$dialog_backtitle" \
      --infobox "importing 'Exported-Validator-Keys'..." 0 0

    ansible-playbook \
      -e validator_number="$importing_validator_number" \
      -e validator_mnemonic="$choice_validator_mnemonic" \
      -v \
      "${install_path}/ethereum2-ansible/import-validator-accounts.yaml" \
      > /dev/null 2>&1

  else

    dialog --backtitle "$dialog_backtitle" \
      --infobox "importing 'Exported-Validator-Keys'..." 0 0

    ansible-playbook \
      -e validator_keys_path="/tmp/exported-config" \
      -e validator_password="$exported_validator_password" \
      -v \
      "${install_path}/ethereum2-ansible/import-validator-accounts.yaml" \
      > /dev/null 2>&1
  fi

  rm -rf /tmp/exported-config

  dialog --clear
}

check_privileges
check_dependencies
dialog_welcome
dialog_import_config
if [ $choice_import_config == 0 ]; then
  dialog_path
  dialog_install_progress
  if [ $choice_import_validator == 0 ]; then
    dialog_import_validator
  fi
  dialog_installation_successful
else
  dialog_path
  dialog_client
  dialog_network
  dialog_overrides
  dialog_auto_updates
  dialog_install_progress
  dialog_installation_successful
fi

# EOF
