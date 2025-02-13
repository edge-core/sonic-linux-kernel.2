.ONESHELL:
SHELL = /bin/bash
.SHELLFLAGS += -e

KVERSION_SHORT ?= 3.16.0-9
KVERSION ?= $(KVERSION_SHORT)-amd64
KERNEL_VERSION ?= 3.16.68
KERNEL_SUBVERSION ?= 2

MAIN_TARGET = linux-headers-$(KVERSION_SHORT)-common_$(KERNEL_VERSION)-$(KERNEL_SUBVERSION)_amd64.deb
DERIVED_TARGETS = linux-headers-$(KVERSION)_$(KERNEL_VERSION)-$(KERNEL_SUBVERSION)_amd64.deb \
                 linux-image-$(KVERSION)_$(KERNEL_VERSION)-$(KERNEL_SUBVERSION)_amd64.deb

DSC_FILE = linux_$(KERNEL_VERSION)-$(KERNEL_SUBVERSION).dsc
ORIG_FILE = linux_$(KERNEL_VERSION).orig.tar.xz
DEBIAN_FILE = linux_$(KERNEL_VERSION)-$(KERNEL_SUBVERSION).debian.tar.xz
URL = http://security.debian.org/debian-security/pool/updates/main/l/linux
BUILD_DIR=linux-$(KERNEL_VERSION)

DSC_FILE_URL = "https://sonicstorage.blob.core.windows.net/packages/kernel-public/$(DSC_FILE)?sv=2015-04-05&sr=b&sig=lahykPRvH4dCs41jqThZ7xLToXpsaI5b5NaF%2FkvaFCY%3D&se=2047-02-22T19%3A40%3A52Z&sp=r"
DEBIAN_FILE_URL = "https://sonicstorage.blob.core.windows.net/packages/kernel-public/$(DEBIAN_FILE)?sv=2015-04-05&sr=b&sig=V1ead7EZm6qDxwKGjtabE1s8xKfl%2BoB104rmmg9%2FQvs%3D&se=2047-02-22T19%3A40%3A15Z&sp=r"
ORIG_FILE_URL = "https://sonicstorage.blob.core.windows.net/packages/kernel-public/$(ORIG_FILE)?sv=2015-04-05&sr=b&sig=fY0MvyciZaIPynbpowo2ADEsjdi0WZ0dMYM6xvQDd80%3D&se=2047-02-22T19%3A42%3A02Z&sp=r"

$(addprefix $(DEST)/, $(MAIN_TARGET)): $(DEST)/% :
	# Obtaining the Debian kernel source
	rm -rf $(BUILD_DIR)
	wget -O $(DSC_FILE) $(DSC_FILE_URL)
	wget -O $(ORIG_FILE) $(ORIG_FILE_URL)
	wget -O $(DEBIAN_FILE) $(DEBIAN_FILE_URL)

	dpkg-source -x $(DSC_FILE)

	pushd $(BUILD_DIR)
	git init
	git add -f *
	git commit -m "original source files"

	# patch debian changelog and update kernel package version
	git am ../patch/changelog.patch

	# re-generate debian/rules.gen, requires kernel-wedge
	debian/bin/gencontrol.py

	# generate linux build file for amd64_none_amd64
	fakeroot make -f debian/rules.gen setup_amd64_none_amd64

	# Applying patches and configuration changes
	git --no-pager diff
	git add debian/build/build_amd64_none_amd64/.config -f
	git add debian/config.defines.dump -f
	git commit -m "unmodified debian source"
	stg init
	stg import -s ../patch/series
	stg status
	stg series

	# Building a custom kernel from Debian kernel source
	fakeroot make -f debian/rules.gen -j $(shell nproc) binary-arch_amd64_none
	popd

ifneq ($(DEST),)
	mv $(DERIVED_TARGETS) $* $(DEST)/
endif

$(addprefix $(DEST)/, $(DERIVED_TARGETS)): $(DEST)/% : $(DEST)/$(MAIN_TARGET)
