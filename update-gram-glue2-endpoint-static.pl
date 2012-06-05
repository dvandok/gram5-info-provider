#!/usr/bin/perl -w
#
# gram5-glue2-endpoint-static: an information provider for the 
# static part of the Endpoint object, in v 2.0 of the GLUE schema
# It can be installed as a gip provider or, even better, it can be called
# just once to produce a ldif part to be installed in the ldif
# gip directory
#
# Author: Dennis van Dok
# Based on glite-info-glue2-endpoint by Stephen Burke
# with modifications by Massimo Sgaravatto and David Groep.

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
use Crypt::OpenSSL::X509;

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
my $outfile = $outputdir . "/ComputingEndpoint.ldif";
open OUT, ">", $outfile or die "Can't open $outfile for writing, stopped";


# Determine this host.
chomp(my $hostname = `hostname -f`);
my $host = ($ce{top}{node} || $hostname);

die "Missing $host section in ce.conf, stopped" unless $ce{$host};
my $n = $ce{$host};

my $clustername = $$n{cluster};
my $c = $cluster{$clustername} or die "Missing cluster $clustername in cluster.conf, stopped";

# Get service id from conf file. This is a cluster property (cf. gLite CLUSTER)
my $ServiceID = $$c{ComputingServiceID} or die "Missing ComputingServiceID in $clustername, stopped";

# EndPointId is ServiceId + "_org.globus.gram"
my $EndPointId = $ServiceID . "_org.globus.gram";

my $bind_dn = "GLUE2ServiceID=$ServiceID,GLUE2GroupID=resource,o=glue";


# Now start outputting LDIF lines for the Endpoint object.
# Note that once we get here we are committed to printing a
# complete, valid object. Start with the DN ...

print OUT "dn: GLUE2EndpointID=$EndPointId,$bind_dn\n";

# Print the boilerplate objectclass declarations and unique ID

print OUT "objectClass: GLUE2Entity\n";
print OUT "objectClass: GLUE2Endpoint\n";
print OUT "objectClass: GLUE2ComputingEndpoint\n";

# Times are mandated to be UTC only
my $TimeNow = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());
print OUT "GLUE2EntityCreationTime: $TimeNow\n";

# No validity, since this is static info

# Print GLUE2EndpointID:
print OUT "GLUE2EndpointID: $EndPointId\n";

# The name is just an indicative human-readable string.
# Let's use the EndPointId for the name 
print OUT "GLUE2EntityName: $EndPointId\n";


# HostDN among the otherinfo info

# Host cert location is currently hard-wired
my $hostcert = "/etc/grid-security/hostcert.pem";

$hostcert = "./hostcert.pem" if $debug;

# Get Host DN using openssl command

my $x509 = Crypt::OpenSSL::X509->new_from_file($hostcert);
my $HostDN = $x509->subject();
print OUT "GLUE2EntityOtherInfo: HostDN=$HostDN\n";

# Embed some metadata to help with debugging

print OUT "GLUE2EntityOtherInfo: InfoProviderName=gram5-glue2-endpoint-static\n";
print OUT "GLUE2EntityOtherInfo: InfoProviderVersion=$version\n";
print OUT "GLUE2EntityOtherInfo: InfoProviderHost=$host\n";

# Version number for IGE, hardwired for now
print OUT "GLUE2EntityOtherInfo: MiddlewareName=IGE\n";
print OUT "GLUE2EntityOtherInfo: MiddlewareVersion=5.2\n";


# Endpoint URL of the GRAM5
my $Endpoint = "httpg://" . $host . ":2119/";
print OUT "GLUE2EndpointURL: $Endpoint\n";

# Capability of the endpoint
print OUT "GLUE2EndpointCapability: executionmanagement.jobexecution\n";

print OUT "GLUE2EndpointTechnology: http/1.1\n";
print OUT "GLUE2EndpointInterfaceName: org.globus.gram\n";
print OUT "GLUE2EndpointInterfaceVersion: 2\n";
print OUT "GLUE2EndpointImplementor: globus\n";
print OUT "GLUE2EndpointImplementationName: GRAM\n";
# FIXME: get data from /etc/globus/globus-gram-job-manager.conf
print OUT "GLUE2EndpointImplementationVersion: 5.2\n";

# Quality level is production
print OUT "GLUE2EndpointQualityLevel: production\n";


# Hardwired value for GLUE2EndpointHealthState and GLUE2EndpointHealthStateInfo
# The real values are supposed to be provided by the dynamic plugin
print OUT "GLUE2EndpointHealthState: unknown\n";
print OUT "GLUE2EndpointHealthStateInfo: N/A\n";


# ServingState is read from conf file
my $GLUE2EndpointServingState = lc $$n{Status};

print OUT "GLUE2EndpointServingState: $GLUE2EndpointServingState\n";

# Issuer CA

my $Issuer = "";
if ( -e $hostcert) {
    $Issuer = $x509->issuer();
}

# Output whatever it gave us, if anything
if ($Issuer) {
    print OUT "GLUE2EndpointIssuerCA: $Issuer\n";
}

# TrustedCA: hardwired for now
my @TrustedCA = "IGTF";
foreach (@TrustedCA) {
    if ($_) {
        print OUT "GLUE2EndpointTrustedCA: $_\n";
    }
}


# Downtimes are handled by the GOC DB, so not published here

print OUT "GLUE2EndpointDownTimeInfo: See the GOC DB for downtimes: https://goc.egi.eu/\n";


# Staging
print OUT "GLUE2ComputingEndpointStaging: staginginout\n";

# Job Description
print OUT "GLUE2ComputingEndpointJobDescription: globus:rsl\n";

# Finally print the upward link to the parent Service
print OUT "GLUE2EndpointServiceForeignKey: $ServiceID\n";
print OUT "GLUE2ComputingEndpointComputingServiceForeignKey: $ServiceID\n";

# print a newline to finish the object
print OUT "\n";


# That's it for the Endpoint, now start on the Access Policies

# We need a unique ID for the object - for now take a simple
# solution and just append _Policy to the Endpoint ID. Assume that
# we'll only publish one AP object, i.e. one scheme (the gLite scheme),
# per Endpoint.

my $APUID = $EndPointId . "_Policy";

# Start with the DN ...
print OUT "dn: GLUE2PolicyID=$APUID,GLUE2EndpointID=$EndPointId,$bind_dn\n";

# Print the boilerplate objectclass declarations and unique ID

print OUT "objectClass: GLUE2Entity\n";
print OUT "objectClass: GLUE2Policy\n";
print OUT "objectClass: GLUE2AccessPolicy\n";
print OUT "GLUE2PolicyID: $APUID\n";

# Creation time  
print OUT "GLUE2EntityCreationTime: $TimeNow\n";

# The name is just an indicative human-readable string.
print OUT "GLUE2EntityName: Access control rules for Endpoint $EndPointId\n";

# Embed some metadata to help with debugging
print OUT "GLUE2EntityOtherInfo: InfoProviderName=gram-glue2-endpoint-static\n";
print OUT "GLUE2EntityOtherInfo: InfoProviderVersion=$version\n";
print OUT "GLUE2EntityOtherInfo: InfoProviderHost=$host\n";


# The policy scheme needs a name: arbitrarily define this as org.glite.standard
my $PolicyScheme = "org.glite.standard";

print OUT "GLUE2PolicyScheme: $PolicyScheme\n";

# Now for the actual rules - note that we must have at least one.

# Strip leading and trailing white space - NB DNs may contain spaces.
# Empty lines should not be printed as they aren't valid LDAP, and make
# a basic sanity check for length (Why is length a problem?--DvD)

my @ListOfACBR = split /\s+/, $$n{AccessControlBaseRule};

print OUT "GLUE2PolicyRule: $_\n" foreach @ListOfACBR;



# "ALL" is a reserved word meaning that there is no authz
if (! @ListOfACBR) {
    print OUT "GLUE2PolicyRule: ALL\n";
}

my $Owner = $$n{Owner};
my @ListOfOwner = split /\s+/, $Owner;

print OUT "GLUE2PolicyUserDomainForeignKey: $_\n" foreach @ListOfOwner;

# Finally print the upward link to the parent Endpoint

print OUT "GLUE2AccessPolicyEndpointForeignKey: $EndPointId\n";

# Print a newline to finish the object
print OUT "\n";

exit 0;
