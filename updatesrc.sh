#!/bin/sh
#
# Copyright (c) 2013 Antti Kantee <pooka@iki.fi>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

# This script is somewhat of an amalgamation between NetBSD's
# src/sys/rump/listsrcdirs and buildrump.sh's checkout.sh.

#
# BEGIN SOURCE DATES
#

# date for NetBSD sources
NBSRC_CVSDATE="20140526 1100UTC"
NBSRC_EXTRA='
    20140616 1200UTC:
	src/crypto/external/bsd/openssl'

#
# BEGIN LIST OF FILES
#
files () { pfx=$1; shift; for arg in $* ; do echo src/${pfx}${arg} ; done }

lsfiles () {
	files lib/lib		c crypt ipsec m npf pci prop
	files lib/lib		pthread rmt util y z
	files libexec/		ld.elf_so

	files bin/		cat chmod cp dd df ed ln ls mkdir mv pax
	files bin/		rm rmdir

	files sbin/		cgdconfig chown
	files sbin/		disklabel dump fsck fsck_ext2fs fsck_ffs
	files sbin/		fsck_lfs fsck_msdos fsck_v7fs
	files sbin/		ifconfig mknod
	files sbin/		modstat mount mount_ffs mount_tmpfs newfs
	files sbin/		newfs_v7fs newfs_msdos newfs_ext2fs
	files sbin/		newfs_lfs newfs_sysvbfs newfs_udf
	files sbin/		ping ping6 raidctl reboot
	files sbin/		rndctl route setkey sysctl umount

	files usr.bin/		kdump ktrace
	files usr.sbin/		arp dumpfs makefs ndp npf pcictl vnconfig
	files usr.sbin/		wlanctl

	files external/bsd/	flex libpcap tcpdump wpa
	files crypto/		Makefile.openssl
	files crypto/dist/	ipsec-tools
	files crypto/external/bsd/	openssl
}

#
# BEGIN SCRIPT
#

SRCDIR=./newsrc
export CVSROOT=anoncvs@anoncvs.netbsd.org:/cvsroot
CVSFLAGS="-z3"
GITREPOPUSH='git@github.com:rumpkernel/netbsd-userspace-src'

checkoutcvs ()
{

	mkdir -p ${SRCDIR} || die cannot access ${SRCDIR}
	cd ${SRCDIR} || die cannot access ${SRCDIR}

	# trick cvs into "skipping" the module name so that we get
	# all the sources directly into $SRCDIR
	rm -f src
	ln -s . src

	# now, do the real checkout
	echo '>> step 2: doing cvs checkout'
	lsfiles | xargs ${CVS} ${CVSFLAGS} export \
	    -D "${NBSRC_CVSDATE}" || die checkout failed

	IFS=';'
	for x in ${NBSRC_EXTRA}; do
		IFS=':'
		set -- ${x}
		unset IFS
		date=${1}
		dirs=${2}
		rm -rf ${dirs}
		${CVS} ${CVSFLAGS} export -D "${date}" ${dirs} || die co2
	done

	# One silly workaround for case-insensitive file systems and cvs.
	# Both src/lib/libc/{DB,db} exist.  While the former is empty,
	# since DB exists when db is checked out, they go into the same
	# place.  So in case "DB" exists, rename it to "db" after cvs
	# is done with its business.
	[ -d lib/libc/DB ] && \
	    { mv lib/libc/DB lib/libc/db.tmp ; mv lib/libc/db.tmp lib/libc/db ;}

	# remove the symlink used to trick cvs
	rm -f src
	rm -f listsrcdirs
}

# do a cvs checkout and push the results into the github mirror
githubdate ()
{

	[ -z "$(${GIT} status --porcelain | grep 'M checkout.sh')" ] \
	    || die checkout.sh contains uncommitted changes!
	gitrev=$(${GIT} rev-parse HEAD)

	[ -e ${SRCDIR} ] && die Error, ${SRCDIR} exists

	set -e

	echo '>> step 1: cloning git repository'
	${GIT} clone -n -b netbsd-cvs ${GITREPOPUSH} ${SRCDIR}

	# checkoutcvs does cd to SRCDIR
	checkoutcvs

	echo '>> step 3: adding files to the "netbsd-cvs" branch'
	${GIT} add -A
	echo '>> committing'
	${GIT} commit -m "NetBSD cvs for git rev ${gitrev}"
	echo '>> step 4: merging "netbsd-cvs" to "master"'
	${GIT} checkout master
	${GIT} merge -m 'merge branch "netbsd-cvs" to "master"' netbsd-cvs

	echo '>> final step: commit updatedsrc.sh'
	cp ../updatesrc.sh .
	${GIT} commit updatesrc.sh

	echo '>> Done.  Remember to push ./newsrc after testing'
	echo '>> Use "git diff HEAD^^" to review changes'

	set +e
}

: ${GIT:=git}
: ${CVS:=cvs}

[ -d ${SRCDIR} ] && { echo error: ${SRCDIR} exists already ; exit 1 ; }

githubdate
exit 0
