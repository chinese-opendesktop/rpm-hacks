#!/bin/bash
#
# Deb To Spec: Automatic spec reconstructor
#              Modified from rpm2spec.sh (http://www.barabanov.ru/proj/rpm2spec)
# Ver. 0.0.3, Dec 2012, Robert Wei <robert.wei@ossii.com.tw>
# Ver. 0.0.4, Sep 2015, Wei-Lun Chao <bluebat@member.fsf.org>
#
_PACKAGE="$1"

if [ "$_PACKAGE" = "" -o "$_PACKAGE" = "-h" ]; then
  case $LANG in
    zh_CN*) echo '用法:' $0 '-h|软件包文件' ;;
    zh_TW*) echo '用法:' $0 '-h|套件檔案' ;;
    *) echo 'Usage:' $0 '-h|PACKAGE_NAME|PACKAGE_FILE' ;;
  esac
  exit 0
elif ! (dpkg-deb -h 2>/dev/null >&2) ; then
  case $LANG in
    zh_CN*) echo '错误：dpkg 软件包尚未安装'  >&2 ;;
    zh_TW*) echo '錯誤：dpkg 套件尚未安裝'  >&2 ;;
    *) echo 'Error: dpkg package has not been installed'  >&2 ;;
  esac
  exit 1
elif (dpkg-deb -f "$_PACKAGE" 2>/dev/null >&2); then
  _debQ="dpkg-deb -W --showformat="
else
  case $LANG in
    zh_CN*) echo '错误：不当的软件包文件'  >&2 ;;
    zh_TW*) echo '錯誤：不當的套件檔案'  >&2 ;;
    *) echo 'Error: Bad package file'  >&2 ;;
  esac
  exit 1
fi

LANG=C
Name=$( $_debQ'${Package}' $_PACKAGE )
x=${Name%-dev} ; if [ "$x" != "$Name" ] ; then Name=${x}-devel ; fi
Version=$( $_debQ'${Version}' $_PACKAGE )
Release=${Version#*-}
Version=${Version%%-*}
$_debQ'${Description}' $_PACKAGE | read Summary
echo 'Name:' $Name
echo 'Summary:' $( $_debQ'${Description}' $_PACKAGE | head -n 1)
echo 'Version:' $Version
echo 'Release:' $( sed 's/\.[a-zA-Z].*//' <<< $Release )%{?dist}
echo 'Group:' $( $_debQ'${Section}' $_PACKAGE )
echo 'License: Free Software'
URL=$( $_debQ'${Homepage}' $_PACKAGE )
if [ -n "$URL" ] ; then
  echo 'URL:' $URL
fi
echo 'Source0: http://downloads.sourceforge.net/%{name}/%{name}-%{version}.tar.gz'
BuildArch=$( $_debQ'${Architecture}' $_PACKAGE )
if [ "$BuildArch" = "all" ] ; then
  echo 'BuildArch: noarch'
fi

Requires=$( $_debQ'${Pre-Depends} ${Depends}' $_PACKAGE )
for x in $Requires ; do
  case "$x" in

    ( libc[0-9] | libm.* | rpmlib* | rtld* | libgcc* | librt*) ;;
    ( libgio* | libglib* | libgobject* | libpthread* | base-files ) ;;
    ( libstdc++* ) ;;
    ( */bash | */grep | */bzip2 ) ;;
    ( [0-9]* | \<* | \=* | \>* | \(* ) ;;

    libQt*)         BuildRequires="$BuildRequires\nqt-devel" ;;
    libGL.*)        BuildRequires="$BuildRequires\nlibGL-devel" ;;
    libX11*)        BuildRequires="$BuildRequires\nlibX11-devel" ;;
    libboost*)      BuildRequires="$BuildRequires\nboost-devel" ;; #libboost_filesystem-mt.so libboost_program_options-mt.so libboost_system-mt.so
    libfltk*)       BuildRequires="$BuildRequires\nfltk-devel" ;; # libfltk_images.so.1.3 
    libz.*)         BuildRequires="$BuildRequires\nzlib-devel" ;;
    libcurl*)       BuildRequires="$BuildRequires\nlibcurl-devel" ;;
    libSDL_image*)  BuildRequires="$BuildRequires\nSDL_image-devel" ;;
    libSDL_mixer*)  BuildRequires="$BuildRequires\nSDL_mixer-devel" ;;
    libpango*)      BuildRequires="$BuildRequires\npango-devel" ;; # libpangoft2-1.0.so.0
    libgtk*)        BuildRequires="$BuildRequires\ngtk2-devel" ;;
    libgdk*)        BuildRequires="$BuildRequires\ngdk-pixbuf2-devel" ;;
    liballeg*)      BuildRequires="$BuildRequires\nallegro-devel" ;;
    libogg*)        BuildRequires="$BuildRequires\nlibogg-devel" ;;
    libvorbis*)     BuildRequires="$BuildRequires\nlibvorbis-devel" ;;
    libpng*)        BuildRequires="$BuildRequires\nlibpng-devel" ;;
    libloadpng*)    BuildRequires="$BuildRequires\nallegro-loadpng-devel" ;;
    liblogg*)       BuildRequires="$BuildRequires\nallegro-logg-devel" ;;

    libxtst?)       BuildRequires="$BuildRequires\nlibXtst-devel" ;;
    libncurses*)    BuildRequires="$BuildRequires\nncurses-devel" ;;
    pygobject)      BuildRequires="$BuildRequires\npygobject-devel" ;;
    python)         BuildRequires="$BuildRequires\npython-devel" ;;
    iso-codes)      BuildRequires="$BuildRequires\niso-codes-devel" ;;
    libreadline?)   BuildRequires="$BuildRequires\nreadline-devel" ;;
    zip)            BuildRequires="$BuildRequires\nzip" ;;
    libqtcore4)     BuildRequires="$BuildRequires\nqt4-devel" ;;
     
    *.so*)
            y=${x%.so*}
            y=${y#lib}
            BuildRequires="$BuildRequires\n${y}-devel" ;;

    *) 
        UnonReqs="$UnonReqs $x"
    ;;
  esac
done

Files=$( dpkg-deb -c "$_PACKAGE" | while read x
          do
            x=${x#*.}
            echo "${x%% *}"
          done )

grep "\.desktop *$" <<< "$Files" > /dev/null && BuildRequires="$BuildRequires\ndesktop-file-utils"

for x in $( echo -e "$BuildRequires" | sort -u ) ; do
  echo 'BuildRequires:' $x
done
for x in $UnonReqs ; do
  echo '#Requires:' $x
done

Conflicts=$( $_debQ'${Conflicts} ${Breaks}' $_PACKAGE )
if [ "${Conflicts%% }" != "" ] ; then
  echo '#Conflicts:' $Conflicts
fi

Provides=$( $_debQ'${Provides}' $_PACKAGE )
if [ -n "$Provides" ] ; then
  for Foo in $Provides ; do
    echo 'Provides:' $Foo
  done
fi

echo
echo '%description'
$_debQ'${Description}' $_PACKAGE | tail -n +2 | sed 's/^ //'
echo
echo
echo '%prep'
echo '%setup -q'
echo
echo '%build'
echo '%configure'
echo 'make %{?_smp_mflags}'
echo
echo '%install'
echo 'make install DESTDIR=%{buildroot}'
echo

echo '%files'

Files=$( grep -E -e "^/(etc|var|usr/(bin|sbin|lib|lib64|libexec|include|share|src))" <<< "$Files" | sort )

declare -i lx ly=1
y=""
for x in $Files ; do
  lx=${#x}
  if [ -n "$y" ] && [ "${x:0:$ly}" != "$y" ] ; then
    if [ -z "$Files2" ] ; then Files2="$y"
    else Files2="${Files2} ${y}" ; fi
  fi
  y=""
    
  if [ "${x:$(( $lx - 1 )):1}" = "/" ] ; then
    if  [ "${x#*/${Name}/}" != "$x" ] \
     || [ "${x#*/${Name}-}" != "$x" ] \
     || [ "${x#*/${Name}_}" != "$x" ] \
     || [ "${x#*/${Name}.}" != "$x" ] ; then
      if [ -z "$Files2" ] ; then Files2="$x"
      else Files2="${Files2} ${x}" ; fi
    else
      y=$x
      ly=$lx
    fi
  else
    if [ -z "$Files2" ] ; then Files2="$x"
    else Files2="${Files2} ${x}" ; fi
  fi
done

y="*" ; ly=1
for x in $Files2 ; do
  lx=${#x}
  if [ "${y:$(($ly-1)):1}" != "/" -o "${x:0:$ly}" != "$y" ] ; then

    if [ "$y" = "*" ] ; then Files="$x"
    else Files="${Files}\n${x}" ; fi
    ly=$lx
    y=$x

  fi
done

Files=$( echo -e "$Files" | sed -e "s|/$Name/.*|/$Name/|g" -e "s|/$Name-$Version/.*|/$Name-$Version/|g" -e "s|/$Name-$Version-$Release/.*|/$Name-$Version-$Release/|g" -e 's|^/usr/share/locale/[^/]*/LC_MESSAGES/|/usr/share/locale/*/LC_MESSAGES/|g' -e 's|^/usr/share/man/[^/]*/man|/usr/share/man/*/man|g' | sort -u )

Files=$( sed -e 's|^/usr/share/man|%{_mandir}|g' -e 's|^/usr/share/info|%{_infodir}|g' <<< "$Files" )

Files=$( sed -e 's|^/usr/bin|%{_bindir}|g' -e 's|^/usr/sbin|%{_sbindir}|g' -e 's|^/usr/include|%{_includedir}|g' -e 's|^/usr/share|%{_datadir}|g' -e 's|^/usr/lib64|%{_libdir}|g' -e "s|$Version-$Release|%{version}-%{release}|g" <<< "$Files" )

if [ "$BuildArch" != "noarch" -a "$BuildArch" != "x86_64" ] ; then
  Files=$( sed -e 's|^/usr/lib|%{_libdir}|g' <<< "$Files" )
fi

Files=$( sed -e 's|^/usr/lib/python2\..*/site-packages|%{python_sitelib}|g' -e 's|^%{_libdir}/python2\..*/site-packages|%{python_sitearch}|g' -e 's|^/usr/lib/python3\..*/site-packages|%{python3_sitelib}|g' -e 's|^%{_libdir}/python3\..*/site-packages|%{python3_sitearch}|g' <<< "$Files" )

Files=$( sed -e 's|^/etc|%{_sysconfdir}|g' -e 's|^/usr|%{_prefix}|g' -e "s|$Name|%{name}|g" -e "s|$Version|%{version}|g" <<< "$Files" )

echo -e "$Files"

echo
echo '%changelog'
echo '* '$( date '+%a %b %d %Y' ) "$USER <$USER@$HOSTNAME>"
echo '- Regenerated spec using deb2spec'
