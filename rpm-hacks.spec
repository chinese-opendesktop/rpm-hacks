Name:		rpm-hacks
Version:	2021.4
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
These are useful shell scripts for making or modifying RPM packages.
The 'deb2spec' produce a spec file from a .deb, Debian package file, and the
'rpm2spec' do a similar work but from .rpm file or package installed in a
system.  The 'rpmjail', made with FUSE, is for running RPM in a jailed
environment.  The 'b64shar' can encode any file in to a base64-encoded shell
self-extracting archive.

macros.hacks-srpm provides macros for building compatible projects from
various distributions.

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
%{_rpmconfigdir}/macros.d/macros.hacks-srpm

%changelog
* Sun Apr 25 2021 Wei-Lun Chao <bluebat@member.fsf.org> - 2021.4
- Rebuild
* Thu Dec 20 2012 Robert Wei <robert.wei@ossii.com.tw> - 2012.12
- First build
