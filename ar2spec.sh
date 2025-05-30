#!/usr/bin/bash
_COPYLEFT="MIT License by Wei-Lun Chao <bluebat@member.fsf.org>, 2025.05.09"
_ERROR=true
_BUILDSET=""
_COMPAT=false
while [ -n "$1" ] ; do
    _ERROR=false
    if [ "$1" = '-n' -o "$1" = '--name' ] ; then
        shift
        _NAME="$1"
        [ -z "${_NAME}" ] && _ERROR=true
    elif [ "$1" = '-p' -o "$1" = '--packager' ] ; then
        shift
        _PACKAGER="$1"
        [ -z "${_PACKAGER}" ] && _ERROR=true
    elif [ "$1" = '-s' -o "$1" = '--set' ] ; then
        shift
        _BUILDSET="$1"
        [ -z "${_BUILDSET}" ] && _ERROR=true
    elif [ "$1" = '-C' -o "$1" = '--compat' ] ; then
        _COMPAT=true
    elif [ -z "${_FILE}" -a -f "$1" ] ; then
        _FILE="$1"
    else
        _ERROR=true
    fi
    "${_ERROR}" && break
    shift
done
if "${_ERROR}" ; then
    echo "AR2SPEC: Generating .spec file from software archive" >&2
    echo "${_COPYLEFT}" >&2
    echo "Usage: $(basename $0) [-n|--name PKGNAME] [-p|--packager 'FULLNAME <EMAIL>'] [-s|--set SETTINGS] [-C|--compat] ARCHIVE" >&2
    exit 1
fi

function _initial_variables {
    _USER="$(whoami)"
    _COMMENT=""
    _TEMPDIR="$(mktemp -d)"
    _SUMMARY="No summary"
    _VERSION="0"
    "${_COMPAT}" && _RELEASE="0" || _RELEASE="1"
    _LICENSE="Free Software"
    _GROUP="Applications"
    _SOURCE=$(basename "${_FILE}")
    _URL=""
    _BUILDREQUIRES=""
    _NOARCH=false
    _WITHCXX=false
    _DESCRIPTION="No description."
    _SETUP="-q"
    _BUILDFILE=""
    _BUILDSYS=""
    _SUBDIR=""
    _CFLAGS="-DLINUX -Wno-error -fPIC -fPIE -Wno-format-security -fno-strict-aliasing -Wl,--allow-multiple-definition -Wno-narrowing -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-implicit-int -pipe -lm -lX11 -I/usr/include/tirpc -ltirpc"
    _CXXFLAGS="-Wno-error -fPIC -fPIE -fpermissive -Wno-format-security -fno-strict-aliasing -Wno-range-loop-construct -Wl,--allow-multiple-definition -Wno-narrowing -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-int-conversion -Wno-implicit-int -I/usr/include/qt5 -I/usr/include/qt5/QtWidgets"
    _BUILDCONF=""
    _BUILDMAKE="false"
    _INSTALL="false"
    _DOCS=""
    _DATE=$(LC_ALL=C date '+%a %b %d %Y')
    [ -z "${_PACKAGER}" ] && which git &>/dev/null && _PACKAGER="$(git config user.name) <$(git config user.email)>"
    [ -z "${_PACKAGER}" -o "${_PACKAGER}" = " <>" ] && _PACKAGER="$(getent passwd ${_USER}|cut -d: -f5|cut -d, -f1) <${_USER}@$(hostname)>"
    _LOG="spec generated by ar2spec"
}

function _unpack_archive {
    _FILEEXT="${_FILE##*.}"
    if [ "${_FILEEXT}" = gz -o "${_FILEEXT}" = bz2 -o "${_FILEEXT}" = xz -o "${_FILEEXT}" = Z ] ; then
        tar xf "${_FILE}" -C "${_TEMPDIR}"
        _BASENAME=${_SOURCE%.tar.*}
        _URLSITE="github"
    elif [ "${_FILEEXT}" = tgz -o "${_FILEEXT}" = tbz2 -o "${_FILEEXT}" = txz ] ; then
        tar xf "${_FILE}" -C "${_TEMPDIR}"
        _BASENAME=${_SOURCE%.t*z*}
        _URLSITE="sourceforge"
    elif [ "${_FILEEXT}" = tar ] ; then
        tar xf "${_FILE}" -C "${_TEMPDIR}"
        _BASENAME=${_SOURCE%.tar}
        _URLSITE="sourceforge"
    elif [ "${_FILEEXT}" = zip ] ; then
        unzip -qq "${_FILE}" -d "${_TEMPDIR}"
        _BASENAME=${_SOURCE%.zip}
        _URLSITE="github"
        _BUILDREQUIRES=" unzip"
    elif [ "${_FILEEXT}" = 7z ] ; then
        7za x "${_FILE}" -o"${_TEMPDIR}" > /dev/null
        _BASENAME=${_SOURCE%.7z}
        _URLSITE="sourceforge"
        _BUILDREQUIRES=" p7zip"
    elif [ "${_FILEEXT}" = jar ] ; then
        cp "${_FILE}" "${_TEMPDIR}"
        _BASENAME=${_SOURCE%.jar}
        _URLSITE="sourceforge"
        _SETUP+=" -T"
        [ -n "${_BUILDSET}" ] && _BUILDSET+="\n"
        _BUILDSET+='cp %{SOURCE0} .'
    else
        echo "ERROR! Unrecognized archive: ${_FILE}" >&2
        exit 1
    fi
    [ "${_BASENAME/_/}" != "${_BASENAME}" ] && _URLSITE="sourceforge"
}

function _set_attributes {
    _BASENAME="${_BASENAME/[._-][Ss]ourcecode/}"
    _BASENAME="${_BASENAME/[._-][Ss]ources/}"
    _BASENAME="${_BASENAME/[._-][Ss]ource/}"
    _BASENAME="${_BASENAME/[._-][Ss]rc/}"
    _BASENAME="${_BASENAME/[._-][Rr]elease/}"
    _BASENAME="${_BASENAME/[._-][Ll]inux/}"
    _BASENAME="${_BASENAME/[._-][Aa]ll/}"
    _BASENAME="${_BASENAME/[._-][Oo]rig/}"
    _BASENAME="${_BASENAME/[._-][Pp]ortable/}"
    _BASENAME="${_BASENAME/[._-][Ss]table/}"
    _BASENAME="${_BASENAME/[._-][Ff]ull/}"
    _BASENAME="${_BASENAME/[._-][Cc]urrent/}"
    _PKGNAME="${_BASENAME%%[_-][Vv][0-9]*}"
    [ "${_PKGNAME}" = "${_BASENAME}" ] && _PKGNAME="${_BASENAME%%[-_][0-9]*}"
    [ "${_PKGNAME}" = "${_BASENAME}" ] && _PKGNAME="${_BASENAME%[-_]*}"
    [ "${_PKGNAME}" = "${_BASENAME}" ] && _PKGNAME="${_BASENAME%%[0-9]*}"
    _VERSION="${_BASENAME#${_PKGNAME}}"
    _VERSION="${_VERSION#[-_]}"
    _VERSION="${_VERSION#[Vv]}"
    _VERSION="${_VERSION//[-_]/.}"
    if [ -z "${_VERSION}" ] ; then
        if [ "${_PKGNAME%[0-9]*}" != "${_PKGNAME}" ] ; then
            _VERSION="${_PKGNAME}"
            _PKGNAME="${_PKGNAME%[0-9]*}"
            _VERSION="${_VERSION/${_PKGNAME}/}"
        else
            _VERSION="0"
        fi
    fi
    _PKGNAME="$(echo ${_PKGNAME}|sed -e 's|^[0-9]*-||' -e 's|~[0-9a-z]*_||')"
    [ "${_PKGNAME#lib}" = "${_PKGNAME}" ] && _PKGNAME="${_PKGNAME,,}"
    [ -z "${_NAME}" ] && _NAME="${_PKGNAME/./-}"
    _SRCNAME=${_SOURCE}
    _SRCNAME=${_SRCNAME/${_NAME}/%\{name\}}
    _SRCNAME=${_SRCNAME/${_VERSION}/%\{version\}}
    function _url_github {
#        _URL=$(curl -s --retry 1 'https://github.com/search?q='${_NAME}'&type=repositories'|grep -im1 'https://github.com/[-0-9A-Za-z]*/'${_NAME}'&quot;'|sed 's|.*\(https://github.com/[-0-9A-Za-z]*/'${_NAME}'\).*|\1|i')
        _URL=$(curl -s --retry 1 'https://github.com/search?q='${_NAME}'&type=repositories'|grep -im1 '/<em>'${_NAME}'</em>","hl_trunc_description'|sed 's|/<em>[-0-9A-Za-z_]*</em>","hl_trunc_description|\n|g'|grep -m1 hl_name|sed 's|.*hl_name":"||')
        if [ -n "${_URL}" ] ; then
            _URL="https://github.com/"${_URL}"/"${_NAME}
            _SUMMARY=$(curl -s --retry 1 "${_URL}"|grep -im1 '<title>GitHub'|sed 's|.*<title>GitHub - .*/'${_NAME}': \([^.]*\).*</title>|\1|i')
            if [ "${_VERSION}" = master -o "${_VERSION}" = main ] ; then
                _SOURCE="${_URL}/archive/refs/heads/${_VERSION}.zip#/${_SRCNAME}"
                _RELEASE="0"
            elif wget -q --spider "${_URL}/releases/download/v${_VERSION}/${_SRCNAME}" ; then
                _SOURCE="${_URL}/releases/download/v%{version}/${_SRCNAME}"
            elif wget -q --spider "${_URL}/releases/download/${_VERSION}/${_SRCNAME}" ; then
                _SOURCE="${_URL}/releases/download/%{version}/${_SRCNAME}"
            elif wget -q --spider "${_URL}/archive/refs/tags/v${_VERSION}.tar.gz" ; then
                _SOURCE="${_URL}/archive/refs/tags/v%{version}.tar.gz#/${_SRCNAME}"
            elif wget -q --spider "${_URL}/archive/refs/tags/${_VERSION}.tar.gz" ; then
                _SOURCE="${_URL}/archive/refs/tags/%{version}.tar.gz#/${_SRCNAME}"
            fi
        fi
    }
    function _url_sourceforge {
        if wget -q --spider "https://sourceforge.net/projects/${_NAME}" ; then
            _URL="https://sourceforge.net/projects/${_NAME}"
            _SUMMARY=$(curl -s --retry 1 "${_URL}/"|grep -im1 '<meta name="description" content="Download'|sed 's|<meta name="description" content="Download.*for free\.[ \r]*||'|sed 's|" />||'|sed 's|\..*||')
            if wget -q --spider "${_URL}/files/${_SRCNAME}" ; then
                _SOURCE="${_URL}/files/${_SRCNAME}"
            elif wget -q --spider "${_URL}/files/${_NAME}-${_VERSION}/${_SRCNAME}" ; then
                _SOURCE="${_URL}/files/%{name}-%{version}/${_SRCNAME}"
            elif wget -q --spider "${_URL}/files/${_NAME}/${_VERSION}/${_SRCNAME}" ; then
                _SOURCE="${_URL}/files/%{name}/%{version}/${_SRCNAME}"
            elif wget -q --spider "${_URL}/files/${_NAME}/${_NAME}-${_VERSION}/${_SRCNAME}" ; then
                _SOURCE="${_URL}/files/%{name}/%{name}-%{version}/${_SRCNAME}"
            fi
        fi
    }
    function _url_launchpad {
        if wget -q --spider "https://launchpad.net/${_NAME}" ; then
            _URL="https://launchpad.net/${_NAME}"
            _SUMMARY=$(curl -s --retry 1 "${_URL}"|grep -im1 '<div class="summary"><p>'|sed 's|.*<div class="summary"><p>||'|sed 's|</p></div>||'|sed 's|\.$||')
            if wget -q --spider "${_URL}/${_VERSION}/+download/${_SRCNAME}" ; then
                _SOURCE="${_URL}/%{version}/+download/${_SRCNAME}"
            elif wget -q --spider "${_URL}/trunk/${_VERSION}/+download/${_SRCNAME}" ; then
                _SOURCE="${_URL}/trunk/%{version}/+download/${_SRCNAME}"
            elif wget -q --spider "${_URL}/stable/${_VERSION}/+download/${_SRCNAME}" ; then
                _SOURCE="${_URL}/stable/%{version}/+download/${_SRCNAME}"
            elif wget -q --spider "${_URL}/${_VERSION%.*}/${_VERSION}/+download/${_SRCNAME}" ; then
                _SOURCE="${_URL}/${_VERSION%.*}/%{version}/+download/${_SRCNAME}"
            fi
        fi
    }
    if [ "${_URLSITE}" = github ] ; then
        _url_github
        [ -z "${_URL}" ] && _url_sourceforge
        [ -z "${_URL}" ] && _url_launchpad
    elif [ "${_URLSITE}" = sourceforge ] ; then
        _url_sourceforge
        [ -z "${_URL}" ] && _url_github
        [ -z "${_URL}" ] && _url_launchpad
    fi
    [ -z "${_SUMMARY}" ] && _SUMMARY="No summary"
}

function _enter_directory {
    pushd "${_TEMPDIR}" > /dev/null
    rm -rf __MACOSX/
    _DIRNUM=$(ls|wc -l)
    if [ "${_DIRNUM}" -eq 0 ] ; then
        echo "ERROR! No files found." >&2
        exit 1
    elif [ "${_DIRNUM}" -eq 1 -a -d "$(ls)" ] ; then
        _DIRNAME=$(ls)
        cd "${_DIRNAME}"
        _DIRNAME="${_DIRNAME// /\\ }"
        if [ "${_DIRNAME}" != "${_NAME}-${_VERSION}" ] ; then
            _SETUP+=" -n ${_DIRNAME/${_VERSION}/%\{version\}}"
            _SETUP="${_SETUP/${_NAME}/%\{name\}}"
        fi
    else
        _SETUP+=" -c"
        _DIRNAME="${_NAME}-${_VERSION}"
    fi
    _FINDFILE=$(find . -type f -name '*.spec' -print -quit)
    [ -n "${_FINDFILE}" ] && _COMMENT="See ${_FINDFILE} in Source."
    _FINDFILE=$(find . -type f -iregex '.*\.\(c\|cc\|cpp\|c\+\+\|cxx\|cs\|go\|hs\|pas\|swift\|adb\|f\|f77\|f90\|f95\|rs\|vala\|ml\)' -print -quit)
    if [ -n "${_FINDFILE}" ] ; then
        _NOARCH=false
        _FINDFILE=$(find . -type f -iregex '.*\.\(cc\|cpp\|c\+\+\|cxx\)' -print -quit)
        [ -n "${_FINDFILE}" ] && _WITHCXX=true
    else
        _NOARCH=true
    fi
    for f in COPYING* LICENSE* AUTHORS* NEWS* CHANGELOG* ChangeLog* README* TODO* THANKS* TRANSLATION* *.pdf *.rst *.md *.txt ; do
        if [ -f "$f" -a "$f" != CMakeLists.txt -a "$f" != meson_options.txt -a "${_DOCS/ $f/}" = "${_DOCS}" ] ; then
            [ "${f/ /}" = "$f" ] && _DOCS+=" $f" || _DOCS+=" \"$f\""
        fi
    done
    if [ -n "${_DOCS}" ] ; then
        if grep -qs "GNU Affero General Public License" ${_DOCS} ; then
            _LICENSE="AGPL"
        elif grep -qs "GNU Lesser General Public License" ${_DOCS} ; then
            _LICENSE="LGPL"
        elif grep -qs "GNU General Public License" ${_DOCS} ; then
            _LICENSE="GPL"
        elif grep -qsi "GPL.*license" ${_DOCS} ; then
            _LICENSE="GPL"
        elif grep -qsi "MIT.*license" ${_DOCS} ; then
            _LICENSE="MIT"
        elif grep -qsi "Apache.*license" ${_DOCS} ; then
            _LICENSE="Apache"
        elif grep -qsi "BSD.*license" ${_DOCS} ; then
            _LICENSE="BSD"
        elif grep -qs "AS IS" ${_DOCS} ; then
            _LICENSE="BSD"
        fi
    fi
    function _check_buildsys {
        if [ -f bootstrap ] ; then
            _BUILDSYS="bootstrap"
        elif [ -f bootstrap.sh ] ; then
            _BUILDSYS="bootstrap.sh"
        elif [ -f CMakeLists.txt ] ; then
            _BUILDSYS="cmake"
        elif [ -f autogen.sh ] ; then
            _BUILDSYS="autogen.sh"
        elif [ -f configure.ac -o -f configure.in ] ; then
            _BUILDSYS="autoreconf"
        elif [ -f configure ] ; then
            _BUILDFILE="$(find . -maxdepth 1 -type f -name 'config.guess' -print -quit)"
            _BUILDSYS="configure"
        elif [ -f "$(find . -maxdepth 1 -type f -name '*.pro' -print -quit)" ] ; then
            _BUILDSYS="qmake5"
            grep -qsi qt4 * && _BUILDSYS="qmake4"
            grep -qsi qt6 * && _BUILDSYS="qmake6"
        elif [ -f Imakefile ] ; then
            _BUILDSYS="imake"
        elif [ -f config.sh ] ; then
            _BUILDSYS="config.sh"
        elif [ -f Makefile -o -f makefile -o -f GNUmakefile ] ; then
            _BUILDSYS="make"
        elif [ -f MAKEFILE ] ; then
            [ -n "${_BUILDSET}" ] && _BUILDSET+="\n"
            _BUILDSET+='for f in *;do mv $f ${f,,};done'
            _BUILDSYS="make"
        elif [ -f "$(find . -maxdepth 1 -type f -iregex '.*/makefile.\(linux\|unix\|posix\|gcc\).*' -print -quit)" ] ; then
            _BUILDFILE="$(find . -maxdepth 1 -type f -iregex '.*/makefile.\(linux\|unix\|posix\|gcc\).*' -print -quit)"
            _BUILDSYS="makefile"
        elif [ -f setup.py ] ; then
            _BUILDSYS="python3"
        elif [ -f setup.cfg -o -f pyproject.toml ] ; then
            _BUILDSYS="python-build"
        elif [ -f Cargo.toml ] ; then
            _BUILDSYS="cargo"
        elif [ -f main.go ] ; then
            _BUILDSYS="golang"
        elif [ -f meson.build ] ; then
            _BUILDSYS="meson"
        elif [ -f build.ninja ] ; then
            _BUILDSYS="ninja"
        elif [ -f SConstruct ] ; then
            _BUILDSYS="scons"
        elif [ -f wscript ] ; then
            _BUILDSYS="waf"
        elif [ -f "$(find . -maxdepth 1 -type f -name '*.gemspec' -print -quit)" ] ; then
            _BUILDSYS="gem"
        elif [ -f Rakefile ] ; then
            _BUILDSYS="rake"
        elif [ -f build.xml ] ; then
            _BUILDSYS="ant"
        elif [ -f pom.xml ] ; then
            _BUILDSYS="maven"
        elif [ -f dune ] ; then
            _BUILDSYS="dune"
        elif [ -f "$(find . -maxdepth 1 -type f -name '*.cabal' -print -quit)" ] ; then
            _BUILDSYS="cabal"
        elif [ -f stack.yaml ] ; then
            _BUILDSYS="stack"
        elif [ -f Setup.hs ] ; then
            _BUILDSYS="ghc"
        elif [ -f "$(find . -maxdepth 1 -type f -name '*.nimble' -print -quit)" ] ; then
            _BUILDSYS="nimble"
        elif [ -f Makefile.PL ] ; then
            _BUILDSYS="perl"
        elif [ -f "$(find . -maxdepth 1 -type f -iregex '.*/'${_NAME}'\.\(c\|cc\|cpp\|c\+\+\|cxx\)' -print -quit)" ] ; then
            _BUILDSYS="cc"
        elif [ -f package.json ] ; then
            _BUILDFILE="$(find . -maxdepth 1 -type f -iregex '.*/\('${_NAME}'\|index\).*\.js' -print -quit)"
            _BUILDSYS="nodejs"
        elif [ -f deno.json ] ; then
            _BUILDFILE="$(find . -maxdepth 1 -type f -iregex '.*/\('${_NAME}'\|executable\).*\.ts' -print -quit)"
            _BUILDSYS="deno"
        elif [ -f index.theme ] ; then
            [ -d 16x16 ] && _BUILDSYS="icon-theme" || _BUILDSYS="desktop-theme"
        elif [ -f metacity-theme-1.xml ] ; then
            _BUILDSYS="metacity-theme"
        elif [ -f "$(find . -maxdepth 1 -type f -name '*.tt?' -print -quit)" ] ; then
            _BUILDSYS="fonts"
        elif [ -f "$(find . -maxdepth 1 -type f -name '*.jar' -print -quit)" ] ; then
            _BUILDSYS="jar"
        elif [ -f "$(find . -maxdepth 1 -type f -name '*.lpi' -print -quit)" ] ; then
            _BUILDSYS="lazarus-bin"
        elif [ -f "$(find . -maxdepth 1 -type f -name '*.lpk' -print -quit)" ] ; then
            _BUILDSYS="lazarus-lib"
        elif [ -f "$(find . -maxdepth 1 -type f -name '*.csproj' -print -quit)" ] ; then
            _BUILDSYS="dotnet-csproj"
        elif [ -f "$(find . -maxdepth 1 -type f -name '*.sln' -print -quit)" ] ; then
            _BUILDSYS="dotnet-sln"
        elif [ -f build.zig ] ; then
            _BUILDSYS="zig"
        elif [ -f "$(find . -maxdepth 1 -type f -iregex '.*/'${_NAME}'\.\(py\|pl\|lua\|tcl\)' -print -quit)" ] ; then
            _BUILDFILE="$(find . -maxdepth 1 -type f -iregex '.*/'${_NAME}'\.\(py\|pl\|lua\|tcl\)' -print -quit)"
            _BUILDSYS="script"
        elif [ -f "${_NAME}" ] && file "${_NAME}"|grep -qs text ; then
            _BUILDFILE="${_NAME}"
            _BUILDSYS="script"
        elif [ -f build.sh -o -f make.sh -o -f install.sh ] ; then
            _BUILDSYS="shell"
        elif [ -d usr/bin -o -d usr/share ] ; then
            _BUILDSYS="filesystem"
        fi
    }
    _check_buildsys
    if [ -z "${_BUILDSYS}" ] ; then
        for d in "${_NAME}"/ [Ss]rc*/ [Ss]ource*/ [Ll]inux*/ */ ; do
            if [ -d "$d" ] ; then
                cd "$d"
                _check_buildsys
                cd ..
                if [ -n "${_BUILDSYS}" ] ; then
                    _SUBDIR="${d%/}"
                    break
                fi
            fi
        done
    fi
    _BUILDFILE=${_BUILDFILE#./}
    popd > /dev/null
}

function _set_scripts {
    if [ "${_BUILDSYS}" = bootstrap ] ; then
        _BUILDREQUIRES+=" automake"
        "${_COMPAT}" && _BUILDCONF="chmod +x bootstrap\n./bootstrap||:\n./configure||:" || _BUILDCONF="./bootstrap\n%{configure}"
        "${_COMPAT}" && _BUILDMAKE="make -j1" || _BUILDMAKE="%{make_build}"
        _INSTALL="%{make_install}"
    elif [ "${_BUILDSYS}" = bootstrap.sh ] ; then
        _BUILDREQUIRES+=" automake"
        "${_COMPAT}" && _BUILDCONF="chmod +x bootstrap.sh\n./bootstrap.sh||:\n./configure||:" || _BUILDCONF="./bootstrap.sh\n%{configure}"
        "${_COMPAT}" && _BUILDMAKE="make -j1" || _BUILDMAKE="%{make_build}"
        _INSTALL="%{make_install}"
    elif [ "${_BUILDSYS}" = autogen.sh ] ; then
        _BUILDREQUIRES+=" automake"
        "${_COMPAT}" && _BUILDCONF="chmod +x autogen.sh\n./autogen.sh||:\n./configure||:" || _BUILDCONF="./autogen.sh\n%{configure}"
        "${_COMPAT}" && _BUILDMAKE="make -j1" || _BUILDMAKE="%{make_build}"
        _INSTALL="%{make_install}"
    elif [ "${_BUILDSYS}" = autoreconf ] ; then
        _BUILDREQUIRES+=" automake"
        "${_COMPAT}" && _BUILDCONF="autoreconf -ifv||autoconf||:\n./configure||:" || _BUILDCONF="autoreconf -ifv\n%{configure}"
        "${_COMPAT}" && _BUILDMAKE="make -j1" || _BUILDMAKE="%{make_build}"
        _INSTALL="%{make_install}"
    elif [ "${_BUILDSYS}" = configure ] ; then
        _BUILDREQUIRES+=" automake"
        "${_COMPAT}" && _BUILDCONF="chmod +x configure\n./configure||:" || _BUILDCONF="%{configure}"
        "${_COMPAT}" && _BUILDMAKE="make -j1" || _BUILDMAKE="%{make_build}"
        _INSTALL="%{make_install}"
    elif [ "${_BUILDSYS}" = cmake ] ; then
        _BUILDREQUIRES+=" cmake"
        "${_COMPAT}" && _BUILDCONF="mkdir -p build;cd build;cmake ..||:" || _BUILDCONF="%{cmake}"
        "${_COMPAT}" && _BUILDMAKE="make -j1" || _BUILDMAKE="%{cmake_build}"
        _INSTALL="#cd build;#{make_install}\n%{cmake_install}"
    elif [ "${_BUILDSYS}" = qmake6 ] ; then
        _BUILDREQUIRES+=" qt6-qtbase-devel"
        _CXXFLAGS=${_CXXFLAGS//qt5/qt6}
        "${_COMPAT}" && _BUILDCONF="qmake6 -recursive||:" || _BUILDCONF="%{qmake_qt6}"
        "${_COMPAT}" && _BUILDMAKE="make -j1" || _BUILDMAKE="%{make_build}"
        _INSTALL="%{make_install}"
    elif [ "${_BUILDSYS}" = qmake5 ] ; then
        _BUILDREQUIRES+=" qt5-qtbase-devel"
        "${_COMPAT}" && _BUILDCONF="qmake-qt5 -recursive||:" || _BUILDCONF="%{qmake_qt5}"
        "${_COMPAT}" && _BUILDMAKE="make -j1" || _BUILDMAKE="%{make_build}"
        _INSTALL="%{make_install}"
    elif [ "${_BUILDSYS}" = qmake4 ] ; then
        _BUILDREQUIRES+=" qt4-devel"
        _CXXFLAGS=${_CXXFLAGS/ -I\/usr\/include\/qt5 -I\/usr\/include\/qt5\/QtWidgets/}
        "${_COMPAT}" && _BUILDCONF="qmake-qt4 -recursive||:" || _BUILDCONF="%{qmake_qt4}"
        "${_COMPAT}" && _BUILDMAKE="make -j1" || _BUILDMAKE="%{make_build}"
        _INSTALL="%{make_install}"
    elif [ "${_BUILDSYS}" = imake ] ; then
        _BUILDREQUIRES+=" imake"
        _BUILDCONF="xmkmf -a"
        "${_COMPAT}" && _BUILDMAKE="make -j1" || _BUILDMAKE="%{make_build}"
        _INSTALL="install -Dm755 %{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = config.sh ] ; then
        "${_COMPAT}" && _BUILDCONF="chmod +x config.sh\n./config.sh||:" || _BUILDCONF="bash config.sh"
        "${_COMPAT}" && _BUILDMAKE="make -j1" || _BUILDMAKE="%{make_build}"
        _INSTALL="install -Dm755 %{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = make ] ; then
        "${_COMPAT}" && _BUILDMAKE="make -j1" || _BUILDMAKE="%{make_build}"
        _INSTALL="%{make_install}||install -Dm755 %{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = makefile ] ; then
        "${_COMPAT}" && _BUILDMAKE="make -f ${_BUILDFILE}" || _BUILDMAKE="%{make_build} -f ${_BUILDFILE}"
        _INSTALL="%{make_install} -f ${_BUILDFILE}||install -Dm755 %{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = python3 ] ; then
        _BUILDREQUIRES+=" python3-devel"
        _BUILDMAKE="%{py3_build}"
        _INSTALL="%{py3_install}"
    elif [ "${_BUILDSYS}" = python-build ] ; then
        _BUILDREQUIRES+=" python3-build"
        _BUILDMAKE="python3 -m build"
        _INSTALL="pip install ."
    elif [ "${_BUILDSYS}" = cargo ] ; then
        _BUILDREQUIRES+=" cargo"
        "${_COMPAT}" && _BUILDCONF="cargo update" || _BUILDCONF="cargo clean"
        "${_COMPAT}" && _BUILDMAKE="cargo build -j 1" || _BUILDMAKE="cargo build -j 1 --release"
        _INSTALL="cargo install --root=%{buildroot}%{_prefix} --path=.||install -Dm755 target/release/%{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = golang ] ; then
        _BUILDREQUIRES+=" golang"
        _BUILDMAKE="go build -x"
        _INSTALL="install -Dm755 %{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = meson ] ; then
        _BUILDREQUIRES+=" meson"
        "${_COMPAT}" && _BUILDCONF="meson build" || _BUILDCONF="%{meson}"
        "${_COMPAT}" && _BUILDMAKE="ninja -C build" || _BUILDMAKE="%{meson_build}"
        "${_COMPAT}" && _INSTALL="ninja -C build install" || _INSTALL="%{meson_install}"
    elif [ "${_BUILDSYS}" = ninja ] ; then
        _BUILDREQUIRES+=" ninja-build"
        "${_COMPAT}" && _BUILDMAKE="ninja" || _BUILDMAKE="%{ninja_build}"
        _INSTALL="%{ninja_install}"
    elif [ "${_BUILDSYS}" = scons ] ; then
        _BUILDREQUIRES+=" python3-scons"
        _BUILDMAKE="scons build"
        _INSTALL="scons --install-sandbox=%{buildroot} install"
    elif [ "${_BUILDSYS}" = waf ] ; then
        if [ -x "${_TEMPDIR}"/waf ] ; then
            _BUILDCONF="./waf configure --prefix=%{buildroot}/usr"
            _BUILDMAKE="./waf build"
            _INSTALL="./waf install"
        else
            _BUILDREQUIRES+=" waf"
            _BUILDCONF="waf configure --prefix=%{buildroot}/usr"
            _BUILDMAKE="waf build"
            _INSTALL="waf install"
        fi
    elif [ "${_BUILDSYS}" = gem ] ; then
        _BUILDREQUIRES+=" rubygems-devel"
        _BUILDMAKE="%global gem_name %{name}\ngem build *.gemspec\n%{gem_install}"
        _INSTALL="mkdir -p %{buildroot}%{gem_dir}\ncp -a .%{gem_dir}/* %{buildroot}%{gem_dir}"
    elif [ "${_BUILDSYS}" = rake ] ; then
        _BUILDREQUIRES+=" rubygem-rake"
        _BUILDMAKE="rake"
        _INSTALL="rake install DESTDIR=%{buildroot}"
    elif [ "${_BUILDSYS}" = ant ] ; then
        _BUILDREQUIRES+=" java-devel-openjdk ant"
        _NOARCH=true
        _BUILDMAKE="export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8\nant"
        _INSTALL="install -d %{buildroot}%{_datadir}/%{name}\ncp -a dist/* %{buildroot}%{_datadir}/%{name}"
    elif [ "${_BUILDSYS}" = maven ] ; then
        _BUILDREQUIRES+=" java-devel-openjdk maven"
        _NOARCH=true
        _BUILDMAKE="export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8\nmvn -e package"
        _INSTALL="install -d %{buildroot}%{_datadir}/%{name}\ninstall -m644 %{name}.jar %{buildroot}%{_datadir}/%{name}"
    elif [ "${_BUILDSYS}" = dune ] ; then
        _BUILDREQUIRES+=" ocaml-dune"
        _BUILDMAKE="dune build"
        _INSTALL="dune install --destdir=%{buildroot}"
    elif [ "${_BUILDSYS}" = cabal ] ; then
        _BUILDREQUIRES+=" ghc cabal-install"
        _BUILDCONF="cabal update\ncabal install --only-dependencies"
        _BUILDMAKE="cabal build"
        _INSTALL="cabal install"
    elif [ "${_BUILDSYS}" = stack ] ; then
        _BUILDREQUIRES+=" ghc stack"
        _BUILDMAKE="stack build"
        _INSTALL="stack install"
    elif [ "${_BUILDSYS}" = ghc ] ; then
        _BUILDREQUIRES+=" ghc"
        _BUILDCONF="runhaskell Setup.hs configure"
        _BUILDMAKE="runhaskell Setup.hs build"
        _INSTALL="runhaskell Setup.hs install"
    elif [ "${_BUILDSYS}" = nimble ] ; then
        _BUILDREQUIRES+=" nim"
        _BUILDCONF="nimble setup"
        _BUILDMAKE="nimble build"
        _INSTALL="install -Dm755 %{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = perl ] ; then
        _BUILDREQUIRES+=" perl-devel"
        _NOARCH=true
        _BUILDMAKE="perl Makefile.PL INSTALLDIRS=vendor\n#%{make_build}\nmake -j1"
        _INSTALL="%{make_install}"
    elif [ "${_BUILDSYS}" = cc ] ; then
        "${_COMPAT}" && _BUILDMAKE="make %{name}" || _BUILDMAKE="g++ *.c* -o %{name}"
        _INSTALL="install -Dm755 %{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = nodejs ] ; then
        _BUILDREQUIRES+=" nodejs-devel"
        _NOARCH=true
        _BUILDMAKE="#Disable build for buildsys: ${_BUILDSYS}"
        _INSTALL="mkdir -p %{buildroot}%{nodejs_sitelib}/%{name} %{buildroot}%{_bindir}\ncp -a * %{buildroot}%{nodejs_sitelib}/%{name}"
        _INSTALL+="\nln -s %{nodejs_sitelib}/%{name}/${_BUILDFILE} %{buildroot}%{_bindir}/%{name}\nrm -f %{buildroot}%{nodejs_sitelib}/%{name}/{*.md,LICENSE}"
    elif [ "${_BUILDSYS}" = deno ] ; then
        _BUILDREQUIRES+=" deno"
        _BUILDMAKE="deno compile --output ${_NAME} --allow-read ${_BUILDFILE}"
        _INSTALL="install -Dm755 %{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = icon-theme ] ; then
        _NOARCH=true
        _BUILDMAKE="#Disable build for buildsys: ${_BUILDSYS}"
        _INSTALL="install -d %{buildroot}%{_datadir}/icons/${_SUBDIR:-$_NAME}\ncp -a * %{buildroot}%{_datadir}/icons/${_SUBDIR:-$_NAME}"
    elif [ "${_BUILDSYS}" = desktop-theme ] ; then
        _NOARCH=true
        _BUILDMAKE="#Disable build for buildsys: ${_BUILDSYS}"
        _INSTALL="install -d %{buildroot}%{_datadir}/themes/${_SUBDIR:-$_NAME}\ncp -a * %{buildroot}%{_datadir}/themes/${_SUBDIR:-$_NAME}"
    elif [ "${_BUILDSYS}" = metacity-theme ] ; then
        _NOARCH=true
        _BUILDMAKE="#Disable build for buildsys: ${_BUILDSYS}"
        if [ -n "${_SUBDIR}" ] ; then
            _INSTALL="install -d %{buildroot}%{_datadir}/themes/${_NAME}\ncp -a * %{buildroot}%{_datadir}/themes/${_NAME}"
        else
            _INSTALL="install -d %{buildroot}%{_datadir}/themes/${_NAME}/metacity-1\ncp -a * %{buildroot}%{_datadir}/themes/${_NAME}/metacity-1"
        fi
    elif [ "${_BUILDSYS}" = fonts ] ; then
        _NOARCH=true
        _BUILDMAKE="#Disable build for buildsys: ${_BUILDSYS}"
        _INSTALL="install -d %{buildroot}%{_datadir}/fonts/${_SUBDIR:-$_NAME}\ncp *.tt? %{buildroot}%{_datadir}/fonts/${_SUBDIR:-$_NAME}"
    elif [ "${_BUILDSYS}" = jar ] ; then
        _RELEASE+=".bin"
        _NOARCH=true
        _BUILDMAKE="#Disable build for buildsys: ${_BUILDSYS}"
        _INSTALL="install -d %{buildroot}%{_datadir}/${_SUBDIR:-$_NAME}\ncp *.jar %{buildroot}%{_datadir}/${_SUBDIR:-$_NAME}"
    elif [ "${_BUILDSYS}" = lazarus-bin ] ; then
        _BUILDREQUIRES+=" lazarus"
        _BUILDMAKE="lazbuild --lazarusdir=%{_libdir}/lazarus --cpu=${HOSTTYPE} --widgetset=gtk2 -B *.lpi"
        _INSTALL="install -Dm755 %{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = lazarus-lib ] ; then
        _BUILDREQUIRES+=" lazarus"
        _BUILDMAKE="lazbuild --lazarusdir=%{_libdir}/lazarus --cpu=${HOSTTYPE} --widgetset=gtk2 -B *.lpk"
        _INSTALL="install -d %{buildroot}%{_libdir}/fpc/%{name}\ncp -a * %{buildroot}%{_libdir}/fpc/%{name}"
    elif [ "${_BUILDSYS}" = dotnet-csproj ] ; then
        _BUILDREQUIRES+=" dotnet-host"
        _BUILDMAKE="dotnet publish *.csproj -c Release --no-self-contained"
        _INSTALL="install -Dm755 bin/Release/*/linux-x64/publish/%{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = dotnet-sln ] ; then
        _BUILDREQUIRES+=" dotnet-host"
        _BUILDMAKE="dotnet build *.sln -c Release"
        _INSTALL="install -Dm755 Bld/Drops/Release/Binaries/net8.0/%{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = zig ] ; then
        _BUILDREQUIRES+=" zig"
        _BUILDMAKE="zig build -Doptimize=ReleaseFast"
        _INSTALL="install -Dm755 zig-out/bin/%{name} %{buildroot}%{_bindir}/%{name}"
    elif [ "${_BUILDSYS}" = script ] ; then
        _BUILDMAKE="#Disable build for buildsys: ${_BUILDSYS}"
        _INSTALL="install -Dm755 ${_BUILDFILE} %{buildroot}%{_datadir}/%{name}/${_BUILDFILE}"
    elif [ "${_BUILDSYS}" = shell ] ; then
        _BUILDMAKE="if [ -f build.sh ];then\nbash build.sh\nelif [ -f make.sh ];then\nbash make.sh\nfi"
        _INSTALL="if [ -f install.sh ];then\nsed -i 's|/usr|%{buildroot}/usr|' install.sh\nbash install.sh\nelse\ninstall -Dm755 %{name} %{buildroot}%{_bindir}/%{name}\nfi"
    elif [ "${_BUILDSYS}" = filesystem ] ; then
        _BUILDMAKE="#Disable build for buildsys: ${_BUILDSYS}"
        _INSTALL="install -d %{buildroot}\ncp -a * %{buildroot}"
        if file `find "${_TEMPDIR}" -type f` | grep -qsm1 ELF ; then
            _RELEASE+=".bin"
            _NOARCH=false
        else
            _NOARCH=true
        fi
    fi
    rm -rf "${_TEMPDIR}"
}

function _output_data {
    [ -n "${_COMMENT}" ] && echo '#' "${_COMMENT}"
    echo '%global __spec_install_post %{nil}'
    echo '%undefine _debugsource_packages'
    echo '%undefine _missing_build_ids_terminate_build'
    "${_COMPAT}" || echo '%undefine _auto_set_build_flags'
    echo
    echo 'Summary:' "${_SUMMARY}"
    echo 'Name:' "${_NAME}"
    echo 'Version:' "${_VERSION}"
    echo 'Release:' "${_RELEASE}"
    echo 'License:' "${_LICENSE}"
    echo 'Group:' "${_GROUP}"
    echo 'Source0:' "${_SOURCE}"
    [ -n "${_URL}" ] && echo 'URL:' "${_URL}"
    [ -n "${_BUILDREQUIRES}" ] && echo 'BuildRequires:'"${_BUILDREQUIRES}"
    if "${_NOARCH}" ; then
        "${_COMPAT}" && echo -n '#'
        echo 'BuildArch: noarch'
    else
        [ "${_RELEASE/.bin/}" != "${_RELEASE}" ] && echo '#ExclusiveArch: x86_64'
    fi
    echo
    echo '%description'
    echo -e "${_DESCRIPTION}"
    echo
    if ! "${_NOARCH}" ; then
        echo '%if 0'
        echo '%package devel'
        echo 'Summary: Development files for %{name}'
        echo 'Requires: %{name} = %{version}-%{release}'
        echo
        echo '%description devel'
        echo 'The %{name}-devel package contains libraries and header files for'
        echo 'developing applications that use %{name}.'
        echo '%endif'
        echo
    fi
    echo '%prep'
    echo '%setup' "${_SETUP}"
    echo
    echo '%build'
    [ -n "${_BUILDSET}" ] && echo -e "${_BUILDSET}"
    [ -n "${_SUBDIR}" ] && echo 'cd' "${_SUBDIR}"
    if [ -f "${_FILE}.set" ] ; then
        cat "${_FILE}.set"
        echo "#An optional ${_FILE}.set has been included." >&2
    elif [ -f "${_NAME}.set" ] ; then
        cat "${_NAME}.set"
        echo "#An optional ${_NAME}.set has been included." >&2
    elif "${_COMPAT}" ; then
        echo "#No optional ${_FILE}.set or ${_NAME}.set to be included." >&2
    fi
    if "${_COMPAT}" ; then
        echo "export CFLAGS=\${CFLAGS/-Werror=format-security/} CFLAGS+=' ${_CFLAGS}' LDFLAGS+=' -Wl,--allow-multiple-definition'"
        "${_WITHCXX}" && echo "export CXXFLAGS=\${CXXFLAGS/-Werror=format-security/} CXXFLAGS+=' ${_CXXFLAGS}' CPPFLAGS+=' ${_CXXFLAGS}'"
        [ "${_BUILDSYS}" = configure ] && echo "cp -f /usr/lib/rpm/redhat/config.* `dirname ./${_BUILDFILE}`"
        "${_WITHCXX}" && _CFLAGS+=" ${_CXXFLAGS}"
        [ "${_BUILDSYS}" = cmake ] && echo -e "rm -f CMakeCache.txt\nsed -i 's|-Wall|${_CFLAGS}|' \`find . -type f -name CMakeLists.txt\`"
        [ "${_BUILDCONF/\/configure/}" != "${_BUILDCONF}" ] && echo "sed -i -e 's|-Wall|${_CFLAGS}|' -e 's|-Werror[=a-z\-]* | |g' \`find . -type f -name 'configure*'\`"
        [ -n "${_BUILDCONF}" ] && echo -e "${_BUILDCONF}"
        [ "${_BUILDMAKE/make/}" != "${_BUILDMAKE}" ] && echo "sed -i -e 's|-Wall|${_CFLAGS}|' -e 's|-Werror[=a-z\-]* | |g' \`find . -type f -name '[Mm]akefile*'\`"
    else
        [ -n "${_BUILDCONF}" ] && echo -e "${_BUILDCONF}"
    fi
    echo -e "${_BUILDMAKE}"
    echo
    echo '%install'
    [ -n "${_SUBDIR}" ] && echo 'cd' "${_SUBDIR}"
    if "${_COMPAT}" ; then
        echo "#Disable install for buildsys: ${_BUILDSYS}"
        echo "#Disable install for buildsys: ${_BUILDSYS}" >&2
        echo -e '%if 0\n'"${_INSTALL}"'\n%endif'
    else
        echo "install -d %{buildroot}%{_bindir} %{buildroot}/usr/local/bin %{buildroot}%{_datadir} %{buildroot}/usr/local/share"
        echo -e "${_INSTALL}"
    fi
    echo
    echo '%files'
    [ -n "${_DOCS}" ] && echo '%doc'"${_DOCS}"
    echo '/'
    echo '%if 0'
    echo '%{_docdir}/%{name}'
    echo '%{_bindir}/%{name}'
    echo '%{_sbindir}/%{name}'
    echo '%{_libexecdir}/%{name}'
    echo '%{_libdir}/*.so.*'
    echo '%{_datadir}/%{name}'
    echo '%{_mandir}/man?/*'
    echo '%{_infodir}/*.info*'
    echo '%{_datadir}/applications/%{name}.desktop'
    echo '%{_datadir}/icons/hicolor/*/*/%{name}.*'
    echo '%{_datadir}/locale/*/LC_MESSAGES/%{name}.mo'
    echo '%{_datadir}/pixmaps/%{name}.*'
    echo '%{_sysconfdir}/%{name}.*'
    echo '%{_sysconfdir}/profile.d/%{name}.*sh'
    echo '%{python3_sitearch}/*'
    echo '%{python3_sitelib}/*'
    echo '%{perl_vendorarch}/*'
    echo '%{perl_vendorlib}/*'
    echo '%{gem_spec}'
    echo '%{gem_instdir}'
    echo '%{nodejs_sitelib}/%{name}'
    echo '%exclude %{gem_cache}'
    echo '%exclude %{_datadir}/icons/*/icon-theme.cache'
    echo '%exclude %{_infodir}/dir'
    echo '%exclude %{_datadir}/perl5/perllocal.pod'
    if ! "${_NOARCH}" ; then
        echo
        echo '%files devel'
        echo '%{_libdir}/*.so'
        echo '%{_libdir}/*.a'
        echo '%{_libdir}/%{name}'
        echo '%{_libdir}/pkgconfig/*.pc'
        echo '%{_libdir}/cmake/%{name}'
        echo '%{_includedir}/*.h'
        echo '%{_includedir}/%{name}'
        echo '%exclude %{_libdir}/*.la'
    fi
    echo '%endif'
    echo
    echo '%changelog'
    echo '*' "${_DATE}" "${_PACKAGER}" '-' "${_VERSION}"
    echo '-' "${_LOG}"
}

_initial_variables
_unpack_archive
_set_attributes
_enter_directory
_set_scripts
_output_data
