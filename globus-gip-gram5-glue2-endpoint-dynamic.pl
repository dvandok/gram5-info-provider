#!/usr/bin/perl -w
#
# gram5-glue2-endpoint-dynamic: an information provider plugin for the 
# dynamic part of the Endpoint object, in v 2.0 of the GLUE schema
# It can be installed as a gip plugin
#
# Author: Dennis van Dok
# Based on glite-info-glue2-endpoint by Stephen Burke,
# with modifications by Massimo Sgaravatto and David Groep.

# Ref: http://www.ogf.org/documents/GFD.147.pdf
#      http://glue20.web.cern.ch/glue20/
# Copyright (c) Members of the EGEE Collaboration. 2010.
# See http://www.eu-egee.org/partners/ for details on the copyright
# holders.
#
#     Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use FileHandle;
use POSIX qw(strftime);
use Site::Configuration;
use Getopt::Long;

my $debug = 0;

GetOptions("debug" => \$debug) or die "Error parsing command line options";

if ($debug) {
  print STDERR q{Entering debugging mode. Configuration read from current directory.
};
  $Site::Configuration::confdir = ".";
}

# Hardwire the data validity period to 1 hour for now
my $validity = "3600";

my %ce = readconfig("ce.conf");
my %cluster = readconfig("cluster.conf");

# Determine this host.
chomp(my $hostname = `hostname -f`);
my $host = ($ce{top}{node} || $hostname);

my $n = $ce{$host};
my $clustername = $$n{cluster};
my $c = $cluster{$clustername} or die "Missing cluster $clustername in cluster.conf, stopped";

# Get service id from conf file. This is a cluster property (cf. gLite CLUSTER)
my $ServiceID = $$c{ComputingServiceID} or die "Missing ComputingServiceID in $clustername, stopped";


my $EndPointId = $ServiceID . "_org.globus.gram";


my $bind_dn = "GLUE2ServiceID=$ServiceID,GLUE2GroupID=resource,o=glue";


# Now start outputting LDIF lines for the Endpoint object.
# Note that once we get here we are committed to printing a
# complete, valid object. Start with the DN ...

print "dn: GLUE2EndpointID=$EndPointId,$bind_dn\n";

# Times are mandated to be UTC only
my $TimeNow = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());
print "GLUE2EntityCreationTime: $TimeNow\n";

# Validity is hardwired above
print "GLUE2EntityValidity: $validity\n";


my $Info = `/sbin/service globus-gatekeeper status`;

# What devilry is this?
my $Status = $? >> 8;

my $Statcode;
if    ($Status == 0) { $Statcode = "ok" }
elsif ($Status == 1) { $Statcode = "critical" }
elsif ($Status == 2) { $Statcode = "warning" }
elsif ($Status == 3) { $Statcode = "unknown" }
else                 { $Statcode = "other" }
print "GLUE2EndpointHealthState: $Statcode\n";
# Info is now optional
if ($Info) {
    trunc($Info);
    print "GLUE2EndpointHealthStateInfo: $Info\n";
}


