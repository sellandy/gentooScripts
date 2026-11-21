# gentooScripts
My used scripts helped my surviving in the gentoo ecosystem :-)


Alias File for nitrogenkernel
Store it in /etc/bash/bashrc.d/nitrogenkernel.sh
alias nitrogenkernel='/etc/kernels/postbuild.d/20-nitrokey.sh && genkernel all'

20-nitrokey.sh
#!/usr/bin/env bash
#
source /etc/genkernel.conf
rm -rf ${INITRAMFS_OVERLAY}
mkdir -p ${INITRAMFS_OVERLAY}/{usr/lib64,usr/bin,lib64,lib,bin,etc}
#NITROLUKS="https://github.com/artosan/nitroluks"
NITROLUKS="https://github.com/amedeos/nitroluks"
INITRD_PATCH="https://raw.githubusercontent.com/amedeos/amedeos.github.io/master/scripts/genkernel/initrd.scripts.patch"
GENKERNEL_DIR="/usr/share/genkernel/defaults"
CRYPT_FILE="initrd.scripts"
GIT_BIN=$(which git)
GPLUS_BIN=$(which g++)
CURL_BIN=$(which curl)
LDD_BIN=$(which ldd)
LD_LINUX=$(whereis ld-linux-x86-64.so.2 | awk '{print $2}')
LIB_SCRIPT="/etc/kernels/postbuild.d/create_lib.sh"
#TODO: insert return codes and check them after every commands

NITROBUILD=$(mktemp -t -d nitrobuild.XXXXX)
${GIT_BIN} clone ${NITROLUKS} ${NITROBUILD}
mkdir -p ${NITROBUILD}/build

${GPLUS_BIN} ${NITROBUILD}/src/nitro_luks.c -o ${NITROBUILD}/build/nitro_luks -L${NITROBUILD}/build/ -l:libnitrokey.so.3 -Wall
cp ${NITROBUILD}/build/nitro_luks ${INITRAMFS_OVERLAY}/bin/
#for f in $(ldd ${NITROBUILD}/build/nitro_luks | egrep "=>" |awk '{print $3}'); do
#       echo "Copy shared libraries $f"
#       mkdir -p "${INITRAMFS_OVERLAY}/$(dirname $f)"
#       cp --dereference ${f}* ${INITRAMFS_OVERLAY}/$(dirname $f)/
#done
#Call own script
echo "Add libs to folders"
${LIB_SCRIPT}

echo "Continue copy scripts!"
cp --dereference ${LD_LINUX} ${INITRAMFS_OVERLAY}/lib/
cp --dereference -a /etc/ld.so.conf.d ${INITRAMFS_OVERLAY}/etc/

echo "Patch initrd"
${CURL_BIN} --output ${NITROBUILD}/initrd.scripts.patch ${INITRD_PATCH}
cp ${GENKERNEL_DIR}/${CRYPT_FILE} ${NITROBUILD}/${CRYPT_FILE}
patch ${NITROBUILD}/${CRYPT_FILE} ${NITROBUILD}/initrd.scripts.patch
cp ${NITROBUILD}/${CRYPT_FILE} ${INITRAMFS_OVERLAY}/etc/${CRYPT_FILE}
rm -rf ${NITROBUILD}
# we need to raise this file in the future, otherwise genkernel will overwrite it in initramfs
TZ=ZZZ0 touch -t "$(TZ=ZZZ-12:00 date +%Y%m%d%H%M.%S)" ${INITRAMFS_OVERLAY}/etc/${CRYPT_FILE}
