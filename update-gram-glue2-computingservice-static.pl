#!/usr/bin/perl -w

#
# gram5-glue2-computingservice-static: an information provider for the 
# static part of the ComputingService object, in v 2.0 of the GLUE schema
# It can be installed as a gip provider or, even better, it can be called
# just once to produce a ldif part to be installed in the ldif
# gip directory
#
# Author: Dennis van Dok
# Based on code by Stephen Burke with adaptations by Massimo Sgaravatto
# and David Groep
# Original Name: gram5-glue2-computingservice-static

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
use POSIX qw(strftime);
use Getopt::Long;
use Site::Configuration;

my $debug = 0;

my $outputdir = "/var/lib/bdii/gip/ldif";

GetOptions("debug" => \$debug) or die "Error parsing command line options";

if ($debug) {
  print STDERR q{Entering debugging mode. Configuration read from current directory;
output files are written to current directory.
};
  $Site::Configuration::confdir = $outputdir = ".";
}

# Version number for this code
my $version = "1.0";


my %ce = readconfig("ce.conf");
my %vo = readconfig("vo.conf");
my %cluster = readconfig("cluster.conf");

# Output files
my $outfile = $outputdir . "/ComputingService.ldif";
open OUT, ">", $outfile or die "Can't open $outfile for writing, stopped";

# Determine this host.
chomp(my $hostname = `hostname -f`);
my $host = ($ce{top}{node} || $hostname);

# This is where we put the object in the DIT
my $bind_dn = "GLUE2GroupID=resource,o=glue";


# Read SiteID from conf file
my $SiteID = $ce{top}{SiteName} or die "SiteName missing in top section of ce.conf, stopped";

die "Missing $host section in ce.conf, stopped" unless $ce{$host};
my $n = $ce{$host};

my $clustername = $$n{cluster};

my $c = $cluster{$clustername} or die "Missing cluster $clustername in cluster.conf, stopped";

# Get service id from conf file. This is a cluster property (cf. gLite CLUSTER)
my $ServiceID = $$c{ComputingServiceID} or die "Missing ComputingServiceID in $clustername, stopped";

# Now start outputting LDIF lines for the ComputingService object.
# Note that once we get here we are committed to printing a
# complete, valid object. Start with the DN ...

print OUT "dn: GLUE2ServiceID=$ServiceID,$bind_dn\n";

# Print the boilerplate objectclass declarations and unique ID

print OUT "objectClass: GLUE2Entity\n";
print OUT "objectClass: GLUE2Service\n";
print OUT "objectClass: GLUE2ComputingService\n";

print OUT "GLUE2ServiceID: $ServiceID\n";
# Creation time and validity are standard attributes for all objects

# Times are mandated to be UTC only
my $TimeNow = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());
print OUT "GLUE2EntityCreationTime: $TimeNow\n";

# No validity, since this is static info

# Name
print OUT "GLUE2EntityName: Computing Service on $host\n";

# Use OtherInfo to embed some metadata to help with debugging

print OUT "GLUE2EntityOtherInfo: InfoProviderName=gram5-glue2-computingservice-static\n";
print OUT "GLUE2EntityOtherInfo: InfoProviderVersion=$version\n";
print OUT "GLUE2EntityOtherInfo: InfoProviderHost=$host\n";


print OUT "GLUE2ServiceCapability: executionmanagement.jobexecution\n";

print OUT "GLUE2ServiceType: org.globus.gram\n";

print OUT "GLUE2ServiceQualityLevel: production\n";

# Count number of shares
# Each VOView makes up one 'share'. Maybe this needs to be revised.
# Our VOviews are the ACBRs for each queue.
# For now, we'll just count queues
my $queues = $$n{queues} || die "no queues defined for $host in ce.conf";

my $ShareCount = split /\s+/, $queues;

# ? Is there only one endpoint for the GRAM service?
my $EndpointCount=1;

# Count number of execution environments
my $ResourceCount = split /\s+/, $$c{subclusters};


print OUT "GLUE2ServiceComplexity: endpointType=$EndpointCount, share=$ShareCount, resource=$ResourceCount\n";

# Upward reference to the hosting site (AdminDomain)

print OUT "GLUE2ServiceAdminDomainForeignKey: $SiteID\n";

# print a newline to finish the object
print OUT "\n";

exit 0;

