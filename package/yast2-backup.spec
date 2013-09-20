#
# spec file for package yast2-backup
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-backup
Version:        3.1.0
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:          System/YaST
License:        GPL-2.0

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:		YaST2 - System Backup
BuildArchitectures:	noarch

BuildRequires:	autoyast2-installation
BuildRequires:	perl-XML-Writer
BuildRequires:	update-desktop-files
BuildRequires:	yast2
BuildRequires:	yast2-devtools >= 3.0.6
BuildRequires:	yast2-nfs-client
BuildRequires:	yast2-testsuite
BuildRequires:	yast2-core >= 2.17.22
BuildRequires:  yast2-slp

Requires:	autoyast2-installation
Requires:	bzip2
Requires:	coreutils
Requires:	e2fsprogs
Requires:	fileutils
Requires:	gzip
Requires:	perl
Requires:	tar
Requires:	util-linux
Requires:	yast2 >= 2.21.22
Requires:	yast2-nfs-client
Requires:	yast2-storage
# ag_freespace
Requires:	yast2 >= 2.18.4

# new builtin lsubstring
Conflicts:	yast2-core < 2.17.22

Recommends:	yast2-bootloader
Recommends:	yast2-network
Recommends:	yast2-tune
Recommends:	yast2-restore

Provides:	yast2-module-backup
Obsoletes:	yast2-module-backup
Provides:	yast2-trans-backup
Obsoletes:	yast2-trans-backup

%description
This package contains a module which searches for changed files and
backs them up.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%files
%defattr(-,root,root)

%dir %{yast_yncludedir}/backup
%{yast_scrconfdir}/proc_filesystems.scr
%{yast_agentdir}/ag_file_append
%{yast_scrconfdir}/cfg_backup.scr
%{yast_yncludedir}/backup/*
%{yast_clientdir}/backup*.rb
%{yast_ybindir}/backup_*
%{yast_moduledir}/Backup.rb
%{yast_desktopdir}/backup.desktop
%doc %{yast_docdir}


