#!/usr/bin/perl -w
#
# glite-ce-glue2-manager-static: an information provider for the
# static part of the Manager object, in v 2.0 of the GLUE schema
# It can be installed as a gip provider or, even better, it can be called
# just once to produce a ldif part to be installed in the ldif
# gip directory
#
# Author: Dennis van Dok
# Based on glite-ce-glue2-manager-static by Massimo Sgaravatto
#
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
use Getopt::Long;
use Site::Configuration;
use Net::LDAP::Entry;
use Net::LDAP::LDIF;

# Version number for this code
my $version = "1.0";

my $debug = 0;

my $outputdir = "/var/lib/bdii/gip/ldif";

GetOptions("debug" => \$debug) or die "Error parsing command line options";

if ($debug) {
  print STDERR q{Entering debugging mode. Configuration read from current directory;
output files are written to current directory.
};
  $Site::Configuration::confdir = $outputdir = ".";
}


my %ce = readconfig("ce.conf");
my %vo = readconfig("vo.conf");
my %cluster = readconfig("cluster.conf");

# Output files
my $outfile = $outputdir . "/ComputingManager.ldif";

#open OUT, ">", $outfile or die "Can't open $outfile for writing, stopped";
my $ldif = Net::LDAP::LDIF->new($outfile, "w");


# Determine this host.
chomp(my $hostname = `hostname -f`);
my $host = ($ce{top}{node} || $hostname);

die "Missing $host section in ce.conf, stopped" unless $ce{$host};
my $n = $ce{$host};

my $clustername = $$n{cluster};
my $c = $cluster{$clustername} or die "Missing cluster $clustername in cluster.conf, stopped";

# Get service id from conf file. This is a cluster property (cf. gLite CLUSTER)
my $ServiceID = $$c{ComputingServiceID} or die "Missing ComputingServiceID in $clustername, stopped";

# ManagerId is ServiceId + "_Manager"
my $ManagerId = $ServiceID . "_Manager";

my $bind_dn = "GLUE2ServiceID=$ServiceID,GLUE2GroupID=resource,o=glue";

# Now start outputting LDIF lines for the Manager object.
# Note that once we get here we are committed to printing a
# complete, valid object. Start with the DN ...
#print "dn: GLUE2ManagerId=$ManagerId,$bind_dn\n";

my $entry = Net::LDAP::Entry->new("GLUE2ManagerId=$ManagerId,$bind_dn");

# Print the boilerplate objectclass declarations and unique ID
#print "objectClass: GLUE2Entity\n";
#print "objectClass: GLUE2Manager\n";
#print "objectClass: GLUE2ComputingManager\n";

$entry->add('objectClass', [qw{GLUE2Entity GLUE2Manager GLUE2ComputingManager}]);

# Times are mandated to be UTC only
my $TimeNow = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());
#print "GLUE2EntityCreationTime: $TimeNow\n";
$entry->add('GLUE2EntityCreationTime', $TimeNow);

# No validity, since this is static info

# Manager Id
#print "GLUE2ManagerID: $ManagerId\n";
$entry->add('GLUE2ManagerID', $ManagerId);
# The name is just an indicative human-readable string.
#print "GLUE2EntityName: Computing Manager on $host\n";
$entry->add('GLUE2EntityName', "Computing Manager on $host");

# Embed some metadata to help with debugging

#print "GLUE2EntityOtherInfo: InfoProviderName=glite-ce-glue2-manager-static\n";
#print "GLUE2EntityOtherInfo: InfoProviderVersion=$version\n";
#print "GLUE2EntityOtherInfo: InfoProviderHost=$host\n";
$entry->add('GLUE2EntityOtherInfo', "InfoProviderName=glite-ce-glue2-manager-static");
$entry->add('GLUE2EntityOtherInfo', "InfoProviderVersion=$version");
$entry->add('GLUE2EntityOtherInfo', "InfoProviderHost=$host");

# ProductName
my $GLUE2ManagerProductName = $$n{lrmstype};

#print "GLUE2ManagerProductName: $GLUE2ManagerProductName\n";
$entry->add('GLUE2ManagerProductName', "$GLUE2ManagerProductName");

# ProductVersion 
my $GLUE2ManagerProductVersion = $$n{lrmsversion};
#print "GLUE2ManagerProductVersion: $GLUE2ManagerProductVersion\n";
$entry->add('GLUE2ManagerProductVersion', "$GLUE2ManagerProductVersion");

# Finally print the upward link to the parent Service
#print "GLUE2ManagerServiceForeignKey: $ServiceID\n";
#print "GLUE2ComputingManagerComputingServiceForeignKey: $ServiceID\n";
$entry->add('GLUE2ManagerServiceForeignKey', $ServiceID);
$entry->add('GLUE2ComputingManagerComputingServiceForeignKey', $ServiceID);

$ldif->write_entry($entry);


