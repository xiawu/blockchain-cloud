#!/bin/bash

set -eu

# Use this script to download the latest NewChain release binary.
# Use USE_NEWCHAIN_VERSION to specify a specific release version.
#   Example: USE_NEWCHAIN_VERSION=v1.8.26 ./newchain.sh

newchain_deploy_latest_version="v20200526"

function color() {
    # Usage: color "31;5" "string"
    # Some valid values for color:
    # - 5 blink, 1 strong, 4 underlined
    # - fg: 31 red,  32 green, 33 yellow, 34 blue, 35 purple, 36 cyan, 37 white
    # - bg: 40 black, 41 red, 44 blue, 45 purple
    printf '\033[%sm%s\033[0m\n' "$@"
}
color "37" ""

system=""
case "$OSTYPE" in
darwin*) system="darwin" ;;
linux*) system="linux" ;;
msys*) system="windows" ;;
cygwin*) system="windows" ;;
*) exit 1 ;;
esac
readonly system

if [ "$system" != "linux" ]; then
    color "31" "Not support's system, please use Ubuntu 18.04 LTS."
    exit 1
fi
color "37" "Current system is $system"

# Check run as root
if [ $EUID -ne 0 ]; then
   color "31" "Run this script with 'sudo $0'"
   exit 1
fi

# get current user
sudo_user="$SUDO_USER"
if [ "$sudo_user" == "" ]; then
  sudo_user="$(whoami)"
fi

color "33" "Current sudo user is $sudo_user"

function get_newchain_version() {
    if [[ -n ${USE_NEWCHAIN_VERSION:-} ]]; then
        readonly reason="specified in \$USE_NEWCHAIN_VERSION"
        readonly newchain_version="${USE_NEWCHAIN_VERSION}"
    else
        # Find the latest NewChain version available for download.
        readonly reason="automatically selected latest available version"
        newchain_version=$(curl -f -s https://release.cloud.diynova.com/newton/newchain/latest.txt) || (color "31" "Get NewChain latest version error." && exit 1)
        readonly newchain_version
    fi
}

get_newchain_version
color "37" "Latest NewChain version is $newchain_version."

newchian_mainnet_file="geth.${newchain_version}"

if [[ -f /data/newchain/mainnet/bin/${newchian_mainnet_file} ]]; then
    color "32" "NewChain is up to date."
    if [[ "$(realpath /data/newchain/mainnet/bin/geth)" != "/data/newchain/mainnet/bin/${newchian_mainnet_file}" ]]; then
      ln -sf "${newchian_mainnet_file}" /data/newchain/mainnet/bin/geth
      color "37" "Updated NewChain binary link."
      supervisorctl restart newchain || {
        color "31" "Failed to restart newchain by supervisor."
        exit 1
      }
    fi

    exit 0
fi

file="geth"
color "34" "Downloading NewChain binary@${newchain_version} to ${file} (${reason})"
color "33" "https://release.cloud.diynova.com/newton/newchain-deploy/mainnet/${file}"
curl -L "https://release.cloud.diynova.com/newton/newchain/${newchain_version}/${system}/${file}" -o $file || {
  color "31" "Failed to download the NewChain binary."
  exit 1
}
curl --silent -L "https://release.cloud.diynova.com/newton/newchain/${newchain_version}/${system}/${file}.sha256" -o "${file}.sha256"
#curl --silent -L "https://release.cloud.diynova.com/newton/newchain/${newchain_version}/${system}/${file}.sig" -o "${file}.sig"
chmod +x $file

color "37" "Trying to verify the downloaded NewChain binary file..."
# TODO: add gpg
sha256sum_res=$(shasum -a 256 -c "${file}.sha256" | awk '{print $2}')
if [ "$sha256sum_res" == "OK" ]; then
    color "32" "Verify $file $sha256sum_res, checksum match."
else
    color "41" "Verify $file $sha256sum_res, checksum did NOT match."
    exit 1
fi

color "37" "Trying to init the work directory..."
mkdir -p /data/newchain/mainnet/bin/
chown -R $sudo_user /data/newchain
mv $file /data/newchain/mainnet/bin/${newchian_mainnet_file}
ln -sf "${newchian_mainnet_file}" /data/newchain/mainnet/bin/geth || {
  color "31" "Failed to link geth to $newchian_mainnet_file."
  exit 1
}
color "37" "Updated NewChain binary link."

# NewChain Deploy file
if [[ ! -x /data/newchain/conf/node.toml ]]; then
  newchain_mainnet_deploy_file="newchain-mainnet-$newchain_deploy_latest_version.tar.gz"

  if [[ ! -x $newchain_mainnet_deploy_file ]]; then
      color "34" "Downloading NewChain installation package@${newchain_mainnet_deploy_file} to ${newchain_mainnet_deploy_file}"
      color "33" "https://release.cloud.diynova.com/newton/newchain-deploy/mainnet/${newchain_mainnet_deploy_file}"
      curl -L "https://release.cloud.diynova.com/newton/newchain-deploy/mainnet/${newchain_mainnet_deploy_file}" -o $newchain_mainnet_deploy_file || {
        color "31" "Failed to download the NewChain installation package."
        exit 1
      }
      curl --silent -L "https://release.cloud.diynova.com/newton/newchain-deploy/mainnet/${newchain_mainnet_deploy_file}.sha256" -o "${newchain_mainnet_deploy_file}.sha256"
      chmod +x $newchain_mainnet_deploy_file
  else
      color "37" "NewChain installation package is up to date."
  fi

  color "37" "Trying to verify the downloaded installation file..."
  # TODO: add gpg
  sha256sum_deploy_res=$(shasum -a 256 -c "${newchain_mainnet_deploy_file}.sha256" | awk '{print $2}')
  if [ "$sha256sum_deploy_res" == "OK" ]; then
      color "32" "Verify $newchain_mainnet_deploy_file $sha256sum_deploy_res, checksum match."
  else
      color "41" "Verify $newchain_mainnet_deploy_file $sha256sum_deploy_res, checksum did NOT match."
      exit 1
  fi

  tar zxf "$newchain_mainnet_deploy_file" -C /data/newchain  || {
    color "31" "Failed to extract $newchain_mainnet_deploy_file to /data/newchain."
    exit 1
  }
  chown -R $sudo_user /data/newchain
  sed -i "s/run_as_username/$sudo_user/g" /data/newchain/mainnet/conf/node.toml
fi

if [[ ! -x /data/newchain/mainnet/nodedata/geth/ ]]; then
  color "37" "Trying to init the NewChain node data directory..."
  /data/newchain/mainnet/bin/geth --datadir /data/newchain/mainnet/nodedata init /data/newchain/mainnet/share/newchainmain.json  || {
    color "31" "Failed to init the NewChain node data directory."
    exit 1
  }
  chown -R $sudo_user /data/newchain
fi

LOGO=$(
      cat <<-END

NNNNNNNNNNNNNNNNNNWX0xoc;'...        ...';cox0XWNNNNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNWNOd:'....,:coddxxxxxxddoc:,....':dONWNNNNNNNNNNNNNN
NNNNNNNNNNNNXkl,...;lxOXNWNNNNNNNNNNNNNNWNXOxl;...,lkXWNNNNNNNNNNN
NNNNNNNNNWKo,..'cxKWNNNNNNNNNNNNNewtonNNNNNNNNNKxc'..,oKWNNNNNNNNN
NNNNNNNW0l. .:xXWNNNNNNNNNNNNNNNNewChainNNNNNNNNNNNWXx:. .l0WNNNNN
NNNNNNKo. .c0WNNNNNNNNNNNNNNNNNNNWWNNNNNNNNWNWNNNNNNWOc. .oKWNNNNN
NNNNNk,..:OWNNNNNNNNNNNNNNNNXkl,:d0NNNNNW0d:,dNNNNNNNNWO:. ,kWNNNN
NNNXo. 'xNNNNNNNNNNNNNNNNNNx,..:dOXNNNNKl..,lOWNNNNNNNNNNx' .oNNNN
NNXl. ;0WNNNNNNNNNNNNNNNNWd..:0WNNNNNNK: .dXNNNNNNNNNNNNNW0; .lXNN
NXl. :KNNNNNNNNNNNNNNNNNN0, ;KNNNNNNNWd..dWNNNNNNNNNNNNNNNNK: .lXN
No. ;0NNNNNNNNNNNNNNNNNNNO' cXWWWWWWWNl .kNNNNNNNNNNNNNNNNNN0; .dW
O' 'kWNNNNNNNNNNNNWXKOkxd:. .:::::::::. .:oxkOKXWNNNNNNNNNNNWk. 'O
c .lNNNNNNNNNWKkoc;'....'.. .:ccccccc:. ..'....';cokKNNNNNNNNNl..c
' 'ONNNNNNW0o;...,coxO0XXk. cNNNNNNNNNl .xXX0Oxoc;...;o0WNNNNNO' '
. ;XNNNNW0c..,okKNNNNNNNNO. cNNNNNNNNNl..kNNNNNNNNKko,..c0WNNNK; .
  cNNNNNK; 'xNNNNNNNNNNNNO. cNNNNNNNNNl .ONNNNNNNNNNNNx' ;0NNNNc
  lNNNNNO' :KNNNNNNNNNNNNO. cNNNNNNNNWl .kNNNNNNNNNNNNX: .ONNNNl
  :XNNNNNo..;xKWNNNNNNNNNO. cNNNNNNNNWl .ONNNNNNNNNWKx;..oNNNNXc
. ,0NNNNNWOc'..;ox0XNWNNNO' cNNNNNNNNNl .kNNNWNX0xo:...cOWNNNN0, .
; .xWNNNNNNWXkl;'...,:codc. ;k0000000k: .cdoc:,...';lkXWNNNNNWx. ;
d. ;KNNNNNNNNNNWX0kdl:;,'.  ...........  .',;:ldk0XWNNNNNNNNNK; .d
X: .oNNNNNNNNNNNNNNNNWWNXx. ;kOOOkkOOk: .dXNWNNNNNNNNNNNNNNNNo. :X
NO, .dNNNNNNNNNNNNNNNNNNNk. lNNNNNNNNNc 'ONNNNNNNNNNNNNNNNNWd. ,ON
NWk' .dNNNNNNNNNNNNNNNNNXc..xWNNNNNNWk' :XNNNNNNNNNNNNNNNNNd. 'kWN
NNWO, .lXNNNNNNNNNNNNNKx,..dNNNNWWXOl..;0NNNNNNNNNNNNNNNNXl. ,OWNN
NNNW0:..;kWNNNNNNNNNNd..'l0WNNNNKx:..;dXNNNNNNNNNNNNNNNWO;..:0WNNN
NNNNNNd' .c0WNNNNNNNW0xkXWNNNNNNNKkx0NNNNNNNNNNNNNNNNW0c. 'dXNNNNN
NNNNNNWKl. .cONNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNOc. .lKWNNNNNN
NNNNNNNNW0l'..,o0NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN0o;..'l0WNNNNNNNN
NNNNNNNNNNWKx:. .,lkKNWNNNNNNNNNNNNNNNNNNNNWNKkl,. .:xKWNNNNNNNNNN
NNNNNNNNNNNNNW0d:'...,coxO0KXNNWWWWNNXK0Oxo:,...':d0WNNNNNNNNNNNNN
NNNNNNNNNNNNNNNNWXOdc;......',,;;;;,,'......;cdOXWNNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNNNNNNWN0xo:,...      ...,:ok0NWNNNNNNNNNNNNNNNNNNNN
END
  )

color "32" "NewChain has been SUCCEESFULLY deployed!"
color "32" "$LOGO"