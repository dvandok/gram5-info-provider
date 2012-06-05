#!/usr/bin/perl -w
#
# glite-ce-glue2-tostorageservice-static: an information provider for the
# static part of the ToStorageService object, in v 2.0 of the GLUE schema
# It can be installed as a gip provider or, even better, it can be called
# just once to produce a ldif part to be installed in the ldif
# gip directory
#
# Author: Dennis van Dok
# Based on glite-ce-glue2-tostorageservice-static from the EGEE project.
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
my %cluster = readconfig("cluster.conf");

# Output files
my $outfile = $outputdir . "/ToStorageService.ldif";

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

my $bind_dn = "GLUE2ServiceID=$ServiceID,GLUE2GroupID=resource,o=glue";


my $CloseSEs = $$n{CloseSEs};

my @list = split /\s+/, $CloseSEs;


# Times are mandated to be UTC only
my $TimeNow = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());

foreach my $SE (@list) {
  my $localpath = $ce{$SE}{exportdir} || "none";
  my $remotepath = $ce{$SE}{mountdir} || "none";

  # GLUE2ToStorageServiceID: concatenation  of serviceid and storageid
  my $GLUE2ToStorageServiceID = $ServiceID . "_" . $SE;

  my $entry = Net::LDAP::Entry->new("GLUE2ToStorageServiceID=$GLUE2ToStorageServiceID,$bind_dn");

  $entry->add('objectClass', [ qw{GLUE2Entity GLUE2ToStorageService}]);

  # Id
  $entry->add('GLUE2ToStorageServiceID', $GLUE2ToStorageServiceID);
  $entry->add('GLUE2EntityCreationTime', $TimeNow);

  # Embed some metadata to help with debugging
  $entry->add('GLUE2EntityOtherInfo', [ "InfoProviderName=glite-ce-glue2-tostorageservice-static",
					"InfoProviderVersion=$version",
					"InfoProviderHost=$host"]);

  # For name let's use the Id
  $entry->add('Glue2EntityName', "$GLUE2ToStorageServiceID");

  # Local Path and remote path
  $entry->add('GLUE2ToStorageServiceLocalPath', $localpath);
  $entry->add('GLUE2ToStorageServiceRemotePath', $remotepath);

  # Upward links
  $entry->add('GLUE2ToStorageServiceComputingServiceForeignKey', $ServiceID);
  $entry->add('GLUE2ToStorageServiceStorageServiceForeignKey', $SE);

  $ldif->write($entry);
}

