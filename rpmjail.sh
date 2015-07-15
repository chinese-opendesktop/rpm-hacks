#!/bin/bash
# rpmjail, MIT License by Wei-Lun Chao <william.chao@ossii.com.tw>, 2009.
# modified after http://extelopedia.wordpress.com/2008/05/24/chroot-jail-with-fusefunionfs/

_JAIL=`mktemp -d`
_APP=`pwd`/"$1"

pushd $_JAIL
rpm2cpio "$_APP" | cpio -id
for i in * ; do
  mv -f $i .$i
done
popd

mkdir -p $_JAIL$HOME $_JAIL/tmp
for i in usr etc bin lib lib64 ; do
  test -d /$i || continue
  mkdir -p $_JAIL/$i
  funionfs -o dirs=/$i=ro $_JAIL/.$i $_JAIL/$i
done
funionfs $HOME $_JAIL$HOME

fakechroot /usr/sbin/chroot $_JAIL "$2"

for i in usr etc bin lib lib64 ; do
  test -d /$i || continue
  fusermount -u $_JAIL/$i
done
fusermount -u $_JAIL$HOME

rm -rf $_JAIL
