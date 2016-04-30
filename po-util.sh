#!/bin/bash
# Particle Offline Utility: A handy script for installing and using the Particle
# Toolchain on Ubuntu-based distros and OSX. This script downloads and installs:
# dfu-util, nodejs, gcc-arm-embedded, particle-cli, and the Particle Firmware
# source code.
# Read more at https://github.com/nrobinson2000/po-util

blue_echo() {
    echo "$(tput setaf 6)$(tput bold) $MESSAGE $(tput sgr0)"
}

green_echo() {
    echo "$(tput setaf 2)$(tput bold) $MESSAGE $(tput sgr0)"
}

red_echo() {
    echo "$(tput setaf 1)$(tput bold) $MESSAGE $(tput sgr0)"
}

if [ "$(uname -s)" == "Darwin" ];
then
modem="$(ls -1 /dev/cu.* | grep -vi bluetooth | tail -1)"
fi

if [ "$(uname -s)" == "Linux" ];
then
modem="$(ls -1 /dev/* | grep "ttyACM" | tail -1)"
fi

CWD="$(pwd)"

if [ "$1" == "install" ];
then
mkdir ~/github
cd ~/github
git clone https://github.com/spark/firmware.git
if [ "$(uname -s)" == "Linux" ];
then
cd ~/github || exit
# Install dependencies
MESSAGE="Installing dependencies..." ; blue_echo
echo
sudo apt-add-repository -y ppa:terry.guo/gcc-arm-embedded
curl -sL https://deb.nodesource.com/setup_5.x | sudo -E bash -
sudo apt-get remove -y node modemmanager gcc-arm-none-eabi

sudo apt-get install -y nodejs python-software-properties python g++ make build-essential libusb-1.0-0-dev gcc-arm-none-eabi libarchive-zip-perl
# Install dfu-util
curl -fsSLO "https://sourceforge.net/projects/dfu-util/files/dfu-util-0.9.tar.gz/download"
tar -xzvf download
rm download
cd dfu-util-0.9 || exit
./configure
make
sudo make install
cd ..
rm -rf dfu-util-0.9

# clone firmware repository
cd ~/github || exit
git clone https://github.com/spark/firmware.git
# install particle-cli
sudo npm install -g node-pre-gyp npm
sudo npm install -g particle-cli
# create udev rules file
curl -fsSLO https://gist.githubusercontent.com/monkbroc/b283bb4da8c10228a61e/raw/e59c77021b460748a9c80ef6a3d62e17f5947be1/50-particle.rules
sudo mv 50-particle.rules /etc/udev/rules.d/50-particle.rules
fi
if [ "$(uname -s)" == "Darwin" ];
then
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew tap PX4/homebrew-px4
brew update
brew install gcc-arm-none-eabi-49 dfu-util
curl -fsSLO https://nodejs.org/dist/v5.8.0/node-v5.8.0.pkg
MESSAGE="Installing nodejs..." ; blue_echo
sudo installer -pkg node-*.pkg -target /
rm node-*.pkg
sudo npm install -g node-pre-gyp npm
sudo npm install -g particle-cli
fi
cd "$CWD" && MESSAGE="Sucessfully Installed!" ; green_echo && exit
fi


if [ "$1" == "init" ];
then
mkdir firmware/
cp *.cpp firmware/
cp *.h firmware/
ls firmware/ | grep -v "particle.include" | cat > firmware/particle.include
MESSAGE="Copied c++ files into firmware directory.  Setup complete." ; green_echo
exit
fi

if [ "$1" == "dfu" ];
then
if [ "$(uname -s)" == "Darwin" ];
then
stty -f "$modem" 19200
sleep 1
dfu-util -d 2b04:d006 -a 0 -i 0 -s 0x080A0000:leave -D "$CWD/bin/firmware.bin"
exit
else
stty -F "$modem" 19200
sleep 1
dfu-util -d 2b04:d006 -a 0 -i 0 -s 0x080A0000:leave -D "$CWD/bin/firmware.bin"
exit
fi
fi

if [ "$1" == "dfu-open" ];
then
if [ "$(uname -s)" == "Darwin" ];
then
stty -f "$modem" 19200
exit
else
stty -F /dev/ttyACM0 19200
exit
fi
fi

if [ "$1" == "dfu-close" ];
then
dfu-util -d 2b04:d006 -a 0 -i 0 -s 0x080A0000:leave -D /dev/null
exit
fi

if [ "$1" == "photon" ] || [ "$1" == "electron" ];
then MESSAGE="$1 selected." ; blue_echo
else
if [ "$1" == "" ];
then
echo "
po-util Copyright (GPL) 2016  Nathan Robinson
This program comes with ABSOLUTELY NO WARRANTY.
Read more at http://bit.ly/po-util

Usage: po DEVICE_TYPE COMMAND DEVICE_NAME
       po DFU_COMMAND

Commands:
  build        Compile code in \"firmware\" subdirectory
  flash        Compile code and flash to device using dfu-util
  clean        Refresh all code
  init         Initialize a new po-util project
  patch        Apply system firmware patch to change baud rate
  update       Download new firmware from Particle
  upgrade      Upgrade system firmware on device
  ota          Upload code Over The Air using particle-cli

DFU Commands:
  dfu         Quickly flash pre-compiled code
  dfu-open    Put device into DFU mode
  dfu-close   Get device out of DFU mode
" && exit
else
  MESSAGE="Please choose \"photon\" or \"electron\"" ; red_echo
fi
fi

cd ~/github/firmware || exit

if [ "$1" == "photon" ];
then git checkout release/v0.5.0
fi

if [ "$1" == "electron" ];
then git checkout release/v0.5.0
fi

if [ "$2" == "upgrade" ] || [ "$2" == "patch" ];
then
cd "$CWD"
sed '2s/.*/START_DFU_FLASHER_SERIAL_SPEED=19200/' ~/github/firmware/build/module-defaults.mk > temp
rm -f ~/github/firmware/build/module-defaults.mk
mv temp ~/github/firmware/build/module-defaults.mk

cd ~/github/firmware/modules/"$1"/system-part1
make clean all PLATFORM="$1" program-dfu

cd ~/github/firmware/modules/"$1"/system-part2
make clean all PLATFORM="$1" program-dfu
cd ~/github/firmware && git stash
sleep 1
dfu-util -d 2b04:d006 -a 0 -i 0 -s 0x080A0000:leave -D /dev/null
exit
fi


if [ "$2" == "update" ];
then git pull
exit
fi

if [ "$2" == "clean" ];
then make clean
exit
fi

if [ "$2" == "ota" ];
then
  if [ "$3" == "" ];
  then MESSAGE="Please specify which device to flash ota." ; red_echo ; exit
fi
particle flash "$3" "$CWD/bin/firmware.bin"
exit
fi

if [ "$2" == "build" ];
then
  cd "$CWD"
  if [ -d firmware ];
  then
    MESSAGE="Found firmware directrory" ; green_echo
  else
    MESSAGE="Firmware directory not found.
Please run \"po init\" to setup this repository or cd to a valid directrory" ; red_echo ; exit
  fi
echo
make all -s -C ~/github/firmware APPDIR="$CWD/firmware" TARGET_DIR="$CWD/bin" PLATFORM="$1" || exit
MESSAGE="Binary saved to $CWD/bin/firmware.bin" ; green_echo
exit
fi

if [ "$2" == "flash" ];
then
  cd "$CWD"
  if [ -d firmware ];
  then
    MESSAGE="Found firmware directrory" ; green_echo
  else
    MESSAGE="Firmware directory not found.
Please run with \"po init\" to setup this repository or cd to a valid directrory" ; red_echo ; exit
  fi

if [ "$(uname -s)" == "Darwin" ];
then
stty -f "$modem" 19200
make all -s -C ~/github/firmware APPDIR="$CWD/firmware" TARGET_DIR="$CWD/bin" PLATFORM="$1" || exit
dfu-util -d 2b04:d006 -a 0 -i 0 -s 0x080A0000:leave -D "$CWD/bin/firmware.bin"
exit

else
stty -F "$modem" 19200
make all -s -C ~/github/firmware APPDIR="$CWD/firmware" TARGET_DIR="$CWD/bin" PLATFORM="$1" || exit
dfu-util -d 2b04:d006 -a 0 -i 0 -s 0x080A0000:leave -D "$CWD/bin/firmware.bin"
exit
fi
fi

MESSAGE="Please choose a command." ; red_echo
