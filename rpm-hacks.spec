Name:		rpm-hacks
Version:	2015.9
Release:	1%{?dist}
Summary:	RPM utilities in shell-script
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
* Thu Sep 03 2015 Wei-Lun Chao <bluebat@member.fsf.org> 2015.9-1
- Rebuild

* Thu Dec 20 2012 Robert Wei <robert.wei@ossii.com.tw> 2012.12-1
- First build
