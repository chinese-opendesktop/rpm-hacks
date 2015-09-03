#!/bin/bash
#
# Rpm To Spec: Automatic spec reconstructor
# Ver. 0.0.1, May 2004, Aleksey Barabanov <alekseybb@mail.ru> http://www.barabanov.ru/proj/rpm2spec
# Ver. 0.0.2, Aug 2012, Kevin Chen <kevin.chen@ossii.com.tw>, Wei-Lun Chao <william.chao@ossii.com.tw>
# Ver. 0.0.3, Dec 2012, Robert Wei <robert.wei@ossii.com.tw>
# Ver. 0.0.4, Sep 2015, Wei-Lun Chao <bluebat@member.fsf.org>
#
_PACKAGE="$1"

if [ "$_PACKAGE" = "" -o "$_PACKAGE" = "-h" ]; then
  case $LANG in
    zh_CN*) echo '用法:' $0 '-h|软件包名称|软件包文件' ;;
    zh_TW*) echo '用法:' $0 '-h|套件名稱|套件檔案' ;;
    *) echo 'Usage: rpm2spec -h|PACKAGE_NAME|PACKAGE_FILE' ;;
  esac
  exit 0
elif (rpm -q "$_PACKAGE" 2>/dev/null >&2); then
  _RPMQ="rpm -q $_PACKAGE"
elif [ "${_PACKAGE%.src.rpm}" != "$_PACKAGE" ] ; then
  rpm2cpio $_PACKAGE | cpio -i --to-stdout '*.spec'
  exit 0
elif (rpm -qp "$_PACKAGE" 2>/dev/null >&2); then
  _RPMQ="rpm -qp $_PACKAGE"
else
  case $LANG in
    zh_CN*) echo '错误：不当的软件包名称或文件'  >&2 ;;
    zh_TW*) echo '錯誤：不當的套件名稱或檔案'  >&2 ;;
    *) echo 'Error: Bad package name or file'  >&2 ;;
  esac
  exit 1
fi

LANG=C
Name=$( $_RPMQ --queryformat=%{name} )
Version=$( $_RPMQ --queryformat=%{version} )
Release=$( $_RPMQ --queryformat=%{release} )
echo 'Name:' $Name
echo 'Summary:' $( $_RPMQ --queryformat=%{summary} )
echo 'Version:' $Version
echo 'Release:' $( sed 's/\.[a-zA-Z].*//' <<< $Release )%{?dist}
echo 'Group:' $( $_RPMQ --queryformat=%{group} )
echo 'License:' $( $_RPMQ --queryformat=%{license} )
echo 'URL:' $( $_RPMQ --queryformat=%{url} )
echo 'Source0: http://downloads.sourceforge.net/project/%{name}/%{name}-%{version}.tar.gz'
BuildArch=$( $_RPMQ --queryformat=%{arch} )
if [ "$BuildArch" == "noarch" ] ; then
  echo 'BuildArch: noarch'
fi

Requires=$( $_RPMQ --requires )
for x in $Requires ; do
  case "$x" in

    ( lib[cm].* | rpmlib* | rtld* | libgcc* | librt* | libgio*) ;;
    ( libglib* | libgobject* | libpthread* | libstdc++* ) ;;
    ( */bash | */sh | */grep | */bzip2 ) ;;
    ( [0-9]* | \<* | \=* | \>*) ;;  

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
     
    *.so*)
            y=${x%.so*}
            y=${y%-[0-9]*}
            y=${y#lib}
            BuildRequires="$BuildRequires\n${y}-devel" ;;

    *) 
        UnonReqs="$UnonReqs $x"
    ;;
  esac
done

Files=$( $_RPMQ -l )
grep "\.desktop *$" <<< "$Files" > /dev/null && BuildRequires="$BuildRequires\ndesktop-file-utils"

for x in $(echo -e "$BuildRequires" | sort -u ) ; do
  echo 'BuildRequires:' $x
done
for x in $UnonReqs ; do
  echo '#Requires:' $x
done

echo
echo '%description'
$_RPMQ -i | sed -n '/^Description/,/^Distribution/p' | grep -v '^\(Description\|Distribution\)'
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
if [ "$( $_RPMQ --scripts )" ] ; then
  $_RPMQ --scripts | sed 's/\(p.*\)install scriptlet (using \/bin\/sh):/\n%\1/'
  echo
fi

echo '%files'

Files=$( grep -E -e "^/(etc|var|usr/(bin|sbin|lib|lib64|libexec|include|share|src))" <<< "$Files" | sort )

declare -i lx ly=1
y="*"
for x in $Files ; do
  lx=${#x}
  if [ "${x:$ly:1}" != "/" -o "${x:0:$ly}" != "$y" ] ; then

    if [ "$y" == "*" ] ; then Files2="$x"
    else Files2="${Files2}\n${x}" ; fi
    ly=$lx
    y=$x

  fi
done

Files=$( echo -e "$Files2" | sed -e "s|/$Name/.*|/$Name|g" -e "s|/$Name-$Version/.*|/$Name-$Version|g" -e "s|/$Name-$Version-$Release/.*|/$Name-$Version-$Release|g" -e 's|^/usr/share/locale/[^/]*/LC_MESSAGES/|/usr/share/locale/*/LC_MESSAGES/|g' -e 's|^/usr/share/man/[^/]*/man|/usr/share/man/*/man|g' | sort -u )
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
echo '- Regenerated spec using rpm2spec'
if [ "$( $_RPMQ --changelog )" ] ; then
  $_RPMQ --changelog
fi
