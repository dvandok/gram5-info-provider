#  File: gram5-info-provider/gram5-info-provider.spec
#  Author: Dennis van Dok <dennisvd@nikhef.nl>
#
#  Copyright 2012  Stichting FOM
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

Summary: GRAM5 information system scripts
Name: gram5-info-provider
Version: 0.1
Release: 1
License: APL 2.0
Group: System Environment/Base
URL: http://www.nikhef.nl/grid
Source: %{name}-%{version}.tar.gz
BuildArch: noarch
Requires: bdii
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot


%description
This package publishes information about the Globus GRAM5 service
to the BDII, a.k.a. the Grid Information System, according to
the GLUE schema (1.3 and 2.0).

%prep
%setup -q

%build

make

%install
rm -rf $RPM_BUILD_ROOT

%makeinstall


%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%{_sbindir}/


%post
# Test to see if the configuration files we need are there
if [ $1 -ge 1 ]; then
   if [ -f /etc/siteinfo/ce.conf ]; then
      %{_sbindir}/update-gram-info-provider
   fi
fi

%changelog
* Sat Jun 2 2012 Dennis van Dok <dennisvd@nikhef.nl> 0.1-1
- Initial build.


