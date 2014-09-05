#
# spec file for package rubygem-ruby-dbus
#
# Copyright (c) 2011 SUSE LINUX Products GmbH, Nuernberg, Germany.
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

# norootforbuild
Name:           rubygem-ruby-dbus
Version:        0.11.0
Release:        0
%define mod_name ruby-dbus
%define mod_full_name %{mod_name}-%{version}
Provides:       ruby-dbus = %{version}
Obsoletes:      ruby-dbus < %{version}
#
Group:          Development/Languages/Ruby
License:        LGPL-2.1
#
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildRequires:  rubygems_with_buildroot_patch
BuildRequires:  rubygem-rake
BuildRequires:  rubygem-packaging_rake_tasks
BuildRequires:  rubygem-nokogiri
BuildRequires:  rubygem-rspec
BuildRequires:  dbus-1
BuildRequires:  netcfg

%rubygems_requires

Requires:       ruby >= 1.9.3
BuildRequires:  ruby-devel >= 1.9.3
#
Url:            https://trac.luon.net/ruby-dbus
Source:         %{mod_full_name}.gem
#
Summary:        Ruby module for interaction with D-Bus
%description
Ruby module for interaction with D-Bus

%package doc
Summary:        RDoc documentation for %{mod_name}
Group:          Development/Languages/Ruby
Requires:       %{name} = %{version}
%description doc
Documentation generated at gem installation time.
Usually in RDoc and RI formats.

%package testsuite
Summary:        Test suite for %{mod_name}
Group:          Development/Languages/Ruby
Requires:       %{name} = %{version}
%description testsuite
Test::Unit or RSpec files, useful for developers.

%prep
%gem_unpack
%gem_build

%build
%install
%gem_install -f

%check
cd %{buildroot}/%{_libdir}/ruby/gems/%{rb_ver}/gems/%{mod_name}-%{version}/spec
rake test TESTOPTS=-v

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
%{_libdir}/ruby/gems/%{rb_ver}/cache/%{mod_full_name}.gem
%{_libdir}/ruby/gems/%{rb_ver}/gems/%{mod_full_name}/
%exclude %{_libdir}/ruby/gems/%{rb_ver}/gems/%{mod_full_name}/spec
%{_libdir}/ruby/gems/%{rb_ver}/specifications/%{mod_full_name}.gemspec

%files doc
%defattr(-,root,root,-)
%doc %{_libdir}/ruby/gems/%{rb_ver}/doc/%{mod_full_name}/

%files testsuite
%defattr(-,root,root,-)
%{_libdir}/ruby/gems/%{rb_ver}/gems/%{mod_full_name}/spec

%changelog
