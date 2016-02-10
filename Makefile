#
# This makefile generates a Snapcraft 2.0 linux-generic amd64 based snap.
#
#
#  Copyright (c) 2015 Canonical
#
#  Author: Tim Gardner <tim.gardner@canonical.com>
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License as
#  published by the Free Software Foundation; either version 2 of the
#  License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
#  USA
#

#
# Set an environment variable if you have an archive proxy
# such as apt-cacher-ng, e.g., 127.0.0.1:3142
#
MIRROR?=http://archive.ubuntu.com/ubuntu/

#
# Install the Snappy PPA in order to pick up advanced features.
#
SNAPPY_PPA?=ppa:snappy-dev/image

#
# Add PPA(s) to perhaps pull in a non-archive kernel package.
#
MY_PPAS?=

LINUX_FLAVOUR?=linux-signed-image-generic
BOOTLOADER?=grub-efi
ARCH?=amd64
SUITE?=xenial

CURRDIR=$(shell pwd)
CHROOT=chroot
KERN=$(CHROOT)/kern
META=$(KERN)/meta
YAML=$(META)/snap.yaml
README=$(META)/readme.md
LIB=$(KERN)/lib
MODULES=$(LIB)/modules
FIRMWARE=$(LIB)/firmware

PPAS=$(foreach p, $(SNAPPY_PPA) $(MY_PPAS), -p $p )

BOOT_FILES = abi config initrd System vmlinuz
LIB_FILES = modules firmware

.PHONY: snap

all: snap

#
# Fetch the rootstock script from the master branch.
# Dirty tricks done dirt cheap.
#
rootstock: ORIGIN=$(shell git remote show origin | grep "Fetch URL:" | sed 's/^.*Fetch URL://')
rootstock:
	rm -rf tmp
	mkdir tmp
	cd tmp; \
	git clone $(ORIGIN) rootstock; \
	cd rootstock; \
	cp rootstock $(CURRDIR)
	rm -rf tmp

build_chroot: rootstock
	sudo sh ./rootstock -a $(ARCH) -f $(LINUX_FLAVOUR) -m $(MIRROR) -s $(SUITE) -b $(BOOTLOADER) $(PPAS) -k
	sudo chmod +r $(CHROOT)/boot/*

snap: clean
	$(MAKE) build_chroot
	#
	sudo mkdir -p $(KERN)
	sudo chown $(USER).$(USER) -R $(KERN)
	mkdir -p $(META)
	#
	echo "name: ubuntu-kernel-$(ARCH)" > $(YAML)
	echo "version: $(shell date '+%Y.%m.%d')" >> $(YAML)
	echo "summary: The ubuntu-core $(ARCH) kernel snap" >> $(YAML)
	echo "architectures: $(ARCH)" >> $(YAML)
	echo "vendor: Canonical" >> $(YAML)
	echo "type: kernel" >> $(YAML)
	#
	cp $(CHROOT)/boot/vmlinuz* $(KERN)
	echo -n "kernel: " >> $(YAML)
	(cd $(KERN); ls -1 vmlinuz-*|tail -n1) >> $(YAML)
	#
	cp $(CHROOT)/boot/initrd* $(KERN)
	echo -n "initrd: " >> $(YAML)
	(cd $(KERN); ls -1 initrd*) >> $(YAML)
	#
	mkdir -p $(MODULES)
	rsync -a $(CHROOT)/lib/modules/ $(MODULES)/
	echo -n "modules: " >> $(YAML)
	(cd $(KERN); ls -d lib/modules/*) >> $(YAML)
	#
	mkdir -p $(FIRMWARE)
	rsync -a $(CHROOT)/lib/firmware/ $(FIRMWARE)/
	echo "firmware: lib/firmware" >> $(YAML)
	#
	sudo chroot $(CHROOT) snappy build `basename $(KERN)`
	sudo mv $(CHROOT)/*.snap .
	sudo chown $(USER).$(USER) *.snap

clean:
	sudo rm -rf $(KERN) *.snap *.log

distclean: clean
	sudo sh ./rootstock -c
