Name:		rpm-hacks
Version:	2022.10
Release:	1
Summary:	RPM hacks utilities
Group:		Applications/Engineering
License:	MIT License
Source0:	%{name}-%{version}.tar.gz
Requires:	dpkg
Requires:	funionfs
Requires:	fakechroot
Requires:	fuse
BuildArch:	noarch

%description
These are useful shell scripts for making or modifying RPM packages:
deb2spec - produce a spec file from a .deb, Debian package file
rpm2spec - produce a spec file from a .rpm package
rpmjail - made with FUSE for running RPM in a jailed environment
b64shar - make any file into a base64-encoded shell self-extracting archive
ar2spec - produce a spec file from a software archive

%prep
%setup -q

%build
make 

%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT install
   
%clean 
rm -rf $RPM_BUILD_ROOT

%files
%doc README
%{_bindir}/*

%changelog
* Sun Oct 30 2022 Wei-Lun Chao <bluebat@member.fsf.org> - 2022.10
- Rebuilt for Fedora
* Thu Dec 20 2012 Robert Wei <robert.wei@ossii.com.tw> - 2012.12
- First build
