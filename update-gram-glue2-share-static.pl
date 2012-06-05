#!/usr/bin/perl -w
#
# glite-ce-glue2-share-static: an information provider for the
# static part of the Share object, in v 2.0 of the GLUE schema
# It can be installed as a gip provider or, even better, it can be called
# just once to produce a ldif part to be installed in the ldif
# gip directory
#
# Author: Dennis van Dok
# Based on the code by Massimo Sgaravatto, with modifications by
# David Groep
# Original name: globus-info-gip-gram5-glue2-share-static
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


#
# Version number for this code
my $version = "1.0";

my %ce = readconfig("ce.conf");
my %vo = readconfig("vo.conf");
my %cluster = readconfig("cluster.conf");

# Output files
my $outfile = $outputdir . "/ComputingShare.ldif";

open OUT, ">", $outfile or die "Can't open $outfile for writing, stopped";

# How do I determine *this* host? FIXME
chomp(my $hostname = `hostname -f`);
my $host = ($ce{top}{node} || $hostname);

# test if the host is defined

die "Missing $host section in ce.conf, stopped" if (!$ce{$host});
my $n = $ce{$host};

my $clustername = $$n{cluster};

my $c = $cluster{$clustername} or die "Missing cluster $clustername in cluster.conf, stopped";

# Get service id from conf file. This is a cluster property (cf. gLite CLUSTER)
my $ServiceID = $$c{ComputingServiceID} or die "Missing ComputingServiceID in $clustername, stopped";

my $bind_dn = "GLUE2ServiceID=$ServiceID,GLUE2GroupID=resource,o=glue";

# Shares are like queues.
my $queues = $$n{queues} || die "no queues defined for $host in ce.conf";

# Times are mandated to be UTC only
my $TimeNow = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());

# GLUE2 Shares are like queues.
for my $qname (split /\s+/, $queues) {
    my $q = $ce{$qname};

    # Without AccessControlBaseRule we can't consider this a 'share'.
    if ($$q{AccessControlBaseRule}) {
	# We have to normalize the rule to have VO: or VOMS: prefixes. Make sure
	# we don't add those if already there.
	my @acl = split /[[:space:]]+/, $$q{AccessControlBaseRule};
	for my $rule (@acl) {
	    next if $rule =~ m/^VO(MS)?:/; # already prefixed
	    next if $rule =~  s,^([^/]),VO:$1,; # FQANs start with a /.
	    next if $rule =~ s,^/,VOMS:/,;
	    # This line can't be reached
	}
	# @acl is now normalised

	# Now start outputting LDIF lines for the Endpoint object.
	# Note that once we get here we are committed to printing a
	# complete, valid object. Start with the DN ...

	# UID for share is concatenation of queue name, VO and ServiceId
	# If the Id is made up of the VO, then multiple ACBRs for the
	# same VO will have to be aggregated (TODO).
	for (@acl) {
	    # derive the VO name to use as a share name
	    my $vo = $_;
	    $vo =~ s,^VO(MS)?:/?([^/]+).*,$2,;

	    my $ShareId = "${qname}_${vo}_${ServiceID}";

	    print OUT "dn: GLUE2ShareID=$ShareId,$bind_dn\n";

	    # Print the boilerplate objectclass declarations and unique ID

	    print OUT "objectClass: GLUE2Entity\n";
	    print OUT "objectClass: GLUE2Share\n";
	    print OUT "objectClass: GLUE2ComputingShare\n";

	    #Shareid
	    print OUT "GLUE2ShareID: $ShareId\n";

	    print OUT "GLUE2EntityCreationTime: $TimeNow\n";

	    # No validity, since this is static info

	    # get lrms from conf file. It is needed to build the ceid
	    my $lrms = lc $$n{lrmstype};
	    
	    # If it is torque use pbs instead

	    $lrms = "pbs" if $lrms eq "torque";


	    my $CEId = $host . ":8443/gram5-" . $lrms . "-$qname";


	    # Embed some metadata to help with debugging
	    print OUT "GLUE2EntityOtherInfo: InfoProviderName=gram5-glue2-share-static\n";
	    print OUT "GLUE2EntityOtherInfo: InfoProviderVersion=$version\n";
	    print OUT "GLUE2EntityOtherInfo: InfoProviderHost=$host\n";

	    # Queue name
	    print OUT "GLUE2ComputingShareMappingQueue: $qname\n";

	    # Default value for Serving state is production
	    # Real value supposed to be provided by the dynamic plugin 

	    # ServingState is read from conf file
	    my $GLUE2EndpointServingState = lc $$n{Status};

	    print OUT "GLUE2ComputingShareServingState: $GLUE2EndpointServingState\n";

	    # Link to the ExecutionEnvironment (only one, the first one, 
	    # for the time being)
	    
	    # Execution Environments are like subclusters
	    # FIXME: only the first EE is considered here. Should have all
	    # EES in proper code.
	    my ($FirstEE) = split /\s+/, $$c{subclusters};

	    print OUT "GLUE2ShareResourceForeignKey: $FirstEE\n";
	    print OUT "GLUE2ComputingShareExecutionEnvironmentForeignKey: $FirstEE\n";

	    # Finally print the upward link to the parent Service
	    print OUT "GLUE2ShareServiceForeignKey: $ServiceID\n";
	    print OUT "GLUE2ComputingShareComputingServiceForeignKey: $ServiceID\n";

	    # Print a newline to finish the object
	    print OUT "\n";

	    # Now printing the GLUE2MappingPolicy objectclass for this share
	    my $bind_dn_policy = "GLUE2ShareId=$ShareId,GLUE2ServiceID=$ServiceID,GLUE2GroupID=resource,o=glue";

	    # PolicyId is ShareId plus "_policy"
	    my $PolicyId = $ShareId . "_policy";

	    # Now start outputting LDIF lines for the GLUE2MappingPolicy object.
	    # Note that once we get here we are committed to printing a
	    # complete, valid object. Start with the DN ...
	    print OUT "dn: GLUE2PolicyID=$PolicyId,$bind_dn_policy\n";

	    #Print the boilerplate objectclass declarations and unique ID
	    print OUT "objectClass: GLUE2Entity\n";
	    print OUT "objectClass: GLUE2Policy\n";
	    print OUT "objectClass: GLUE2MappingPolicy\n";
	    print OUT "GLUE2PolicyID: $PolicyId\n";

	    print OUT "GLUE2EntityCreationTime: $TimeNow\n";

	    # No validity, since this is static info

	    print OUT "GLUE2PolicyScheme: org.glite.standard\n";

	    # remember $_ is the current ACL
	    print OUT "GLUE2PolicyRule: $_\n";

	    # As GLUE2PolicyUserDomainForeignKey print the Owner (==VO)
	    print OUT "GLUE2PolicyUserDomainForeignKey: $vo\n";

	    print OUT "GLUE2MappingPolicyShareForeignKey: $ShareId\n";

	    # Print a newline to finish the object
	    print OUT "\n";
	}
    }
}
         
      

