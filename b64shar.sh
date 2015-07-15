#!/bin/sh
# b64shar, MIT License by Wei-Lun Chao <william.chao@ossii.com.tw>, 2008.

if [ "$1" == "" -o "$1" == "-h" -o "$1" == "--help" ] ; then
  echo "Usage: $0 file ..." >&2
  exit
fi
if ! which base64 2>/dev/null 1>&2 ; then
  echo "base64 NOT installed!" >&2
  exit
fi
echo "Making a base64-encoded shell archive ..." >&2

echo '#!/bin/sh'
echo '# Shell Archive made by b64shar'

while test -n "$1" ; do
  echo
  echo 'echo Extracting '`basename $1`' ...'
  echo 'base64 -i -d > '`basename $1`' << SHAR_EOF'
  base64 $1
  echo 'SHAR_EOF'
  shift
done
