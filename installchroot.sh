#!/bin/sh

CHROOT_PATH='/compat/ubuntu'
UBUNTU_RELEASE='jammy'
RC_SCRIPT='./ubuntu'
MACHINE='amd64'
APT_MIRROR='deb http://archive.ubuntu.com/ubuntu/'
REPOS='main restricted universe multiverse'

chroot_subdirs="
sys
dev
proc
tmp
dev/fd
dev/shm
"

if [ $(id -u) -ne 0 ] ; then
	echo This script requires root permissions
	exit 1
fi

create_chroot_paths() {
	if [ ! -d $CHROOT_PATH ] ; then
		mkdir $CHROOT_PATH
	fi

	for subdir in $chroot_subdirs ; do
		if [ ! -d "$CHROOT_PATH/$subdir" ] ; then
			mkdir "$CHROOT_PATH/$subdir"
		fi
	done

}

install_rc_script() {
	chmod 555 $RC_SCRIPT
	cp $RC_SCRIPT /etc/rc.d/$RC_SCRIPT
}

setup_etc_rc() {
	sysrc linux_enable="NO"
	sysrc ubuntu_enable="YES"
}

start_ubuntu() {
	service ubuntu start
}

install_debootstrap() {
	if ! [ -f /usr/local/sbin/debootstrap ] ; then
		pkg install debootstrap
	fi
	
	# Debootstrap doesn't download as executable for some reason
	if ! [ -x /usr/local/sbin/debootstrap ] ; then
		chmod +x /usr/local/sbin/debootstrap
	fi
}

do_debootstrap() {
	local _sources_list _aptitude

	_sources_list="$CHROOT_PATH/etc/apt/sources.list"
	_aptitude="$CHROOT_PATH/etc/apt/apt.conf.d/00aptitude"
	
	debootstrap --arch=$MACHINE --no-check-gpg $UBUNTU_RELEASE $CHROOT_PATH
	
	echo "$APT_MIRROR $UBUNTU_RELEASE $REPOS" > $_sources_list
	echo "$APT_MIRROR $UBUNTU_RELEASE-security $REPOS" >> $_sources_list
	echo "$APT_MIRROR $UBUNTU_RELEASE-updates $REPOS" >> $_sources_list
	
	# https://wiki.freebsd.org/LinuxApps, says required for apt on
	# Ubuntu 18.04.4 LTS. Might not be needed for jammy.
	echo "APT::Cache-Start 251658240;" > $_aptitude
}

fix_ld_linux() {
	local _lib
	local _lib64

	_lib="$CHROOT_PATH/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"
	_lib64="$CHROOT_PATH/lib64/ld-linux-x86-64.so.2"
	
	if [ ! -f $_lib ] ; then
		echo "Ubuntu install is missing the dnyamic linker '$_lib'"
	fi

	if [ -L $_lib64 ] ; then
		rm -f "$_lib64"
	fi
	
	if [ ! -f $_lib64 ] ; then
		echo copying lib
		cp "$_lib" "$_lib64"
	fi
}

create_chroot_paths
install_rc_script
setup_etc_rc
start_ubuntu
install_debootstrap
do_debootstrap
fix_ld_linux
chmod 1777 /compat/ubuntu/tmp
chroot $CHROOT_PATH /bin/bash -c "apt update"
chroot $CHROOT_PATH /bin/bash -c "apt upgrade"
