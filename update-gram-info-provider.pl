#!/usr/bin/perl -w
#  File: update-gram-info-provider.pl
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

# Derived from config_gip_gram5_glue13

# This script writes the static site information for the CE
# to /var/lib/bdii/ldif/static-file-CE.ldif
#
# This is normally called from %post but may be used by
# site maintainers on update of the configuration.

# Configuration files used:
# /etc/siteinfo/ce.conf
# /etc/siteinfo/cluster.conf
# /etc/siteinfo/vo.conf
#
# These configuration files are INI style conf files. The part
# That concerns the GRAM interface is the CE definition
# and the static part of the VO views.

# In the EGI realm we need to publish a 'CE' for every 'queue'
# (for whatever meaning of that concept) that the CE may accept
# jobs for. This is established practice among many users; instead
# of passing job requirements they point their submission to a
# particular CE/queue combination which represents their requirements.
#
# It is therefore common to have queues that:
# - are named after VOs, which will only accept jobs by users in the VO,
# - are named long/short/medium, with a vague correlation to the maximum
#   time a job may spent computing.
#
# Although this system is flawed, it is not up to us to just stop doing
# this so we carry on in full awareness of the fact that we are just
# prolonging the problem.

# Algorithm:
# Read the configuration files
# Do some sanity checks on the configuration files
# for each queue in this CE (after establishing what 'this CE' is):
#   Write a bucket of ldif to the output
#   For each VO that is allowed to submit to this queue:
#     write the VOViews data to the output
# Done!

# Read the configuration files
use strict;
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

my %ce = readconfig("ce.conf");
my %vo = readconfig("vo.conf");
my %cluster = readconfig("cluster.conf");

# Output files

my $cefile = $outputdir . "/static-file-CE.ldif";
my $sebindfile = $outputdir . "/static-file-CESEBind.ldif";

open CE, ">", $cefile or die "Can't open $cefile for writing, stopped";
open SEBIND, ">", $sebindfile or die "Can't open $sebindfile for writing, stopped";

# How do I determine *this* host? FIXME
chomp(my $hostname = `hostname -f`);
my $node = ($ce{top}{node} || $hostname);

# test if the host is defined

die "Missing $node section in ce.conf, stopped" if (!$ce{$node});


my $n = $ce{$node};

my $queues = $$n{queues} || die "no queues defined for $$node in ce.conf";

my $port = ($$n{port} || 2119);
my $cetype = ($$n{cetype} || "jobmanager");

my $info_port = 2170;
my $info_type = "resource";

my $cecluster = $$n{cluster};


for my $q (split /\s+/, $queues) {

  print CE <<EOF;

dn: GlueCEUniqueID=$$n{hostname}:$port/${cetype}-$$n{jobmanager}-$q,mds-vo-name=resource,o=grid
objectClass: GlueCETop
objectClass: GlueCE
objectClass: GlueCEAccessControlBase
objectClass: GlueCEInfo
objectClass: GlueCEPolicy
objectClass: GlueCEState
objectClass: GlueInformationService
objectClass: GlueKey
objectClass: GlueSchemaVersion
GlueCEUniqueID: $$n{hostname}:$port/$cetype-$$n{jobmanager}-$q
GlueCEHostingCluster: $$n{hostname}
GlueCEName: $q
GlueCEImplementationName: globus
GlueCEImplementationVersion: FIXME
GlueCEInfoGatekeeperPort: $port
GlueCEInfoHostName: $$n{hostname}
GlueCEInfoLRMSType: $$n{lrmstype}
GlueCEInfoLRMSVersion: not defined
GlueCEInfoTotalCPUs: 0
GlueCEInfoJobManager: $$n{jobmanager}
GlueCEInfoContactString: https://$$n{hostname}:$port/jobmanager-$$n{jobmanager}
GlueCEInfoApplicationDir: $$n{ApplicationDir}
GlueCEInfoDataDir: $$n{DataDir}
GlueCEInfoDefaultSE: $$n{DefaultSE}
GlueCEStateEstimatedResponseTime: 2146660842
GlueCEStateFreeCPUs: 0
GlueCEStateRunningJobs: 0
GlueCEStateStatus: $$n{Status}
GlueCEStateTotalJobs: 0
GlueCEStateWaitingJobs: 444444
GlueCEStateWorstResponseTime: 2146660842
GlueCEStateFreeJobSlots: 0
GlueCEPolicyMaxCPUTime: 999999999
GlueCEPolicyMaxRunningJobs: 999999999
GlueCEPolicyMaxTotalJobs: 999999999
GlueCEPolicyMaxWallClockTime: 999999999
GlueCEPolicyMaxObtainableCPUTime: 999999999
GlueCEPolicyMaxObtainableWallClockTime: 999999999
GlueCEPolicyMaxWaitingJobs: 999999999
GlueCEPolicyMaxSlotsPerJob: 999999999
GlueCEPolicyPreemption: 0
GlueCEPolicyPriority: 1
GlueCEPolicyAssignedJobSlots: 0
GlueForeignKey: GlueClusterUniqueID=$cluster{$cecluster}{UniqueID}
GlueInformationServiceURL: ldap://$$n{hostname}:$info_port/mds-vo-name=$info_type,o=grid
GlueSchemaVersionMajor: 1
GlueSchemaVersionMinor: 3
EOF

# TODO: capabilities
  for my $c (split /[[:space:]]+/, $$n{Capability}) {
    print CE "GlueCECapability: $c\n"
  }

# The VOViews per queue.

  my $vo = $ce{$q};

  if ($$vo{AccessControlBaseRule}) {
    # We have to normalize the rule to have VO: or VOMS: prefixes. Make sure
    # we don't add those if already there.
    my @acl = split /[[:space:]]+/, $$vo{AccessControlBaseRule};
    for my $rule (@acl) {
      next if $rule =~ m/^VO(MS)?:/; # already prefixed
      next if $rule =~  s,^([^/]),VO:$1,; # FQANs start with a /.
      next if $rule =~ s,^/,VOMS:/,;
      # This line can't be reached
    }
    print CE "GlueCEAccessControlBaseRule: $_\n" foreach @acl;


    # this logic is hard to peel apart.
    # Some explaination is found in https://savannah.cern.ch/bugs/?25693
    # And some can be taken from http://egee-intranet.web.cern.ch/egee-intranet/NA1/TCG/wgs/Job%20Priorities%20Implementation%20Plan.doc
    #
    # The gist of it is that it's a hack. For matchmaking, the WMS can't (or could not)
    # select the 'most specific' VOView, so it would consider VO:atlas (a catch-all VOView)
    # instead of, e.g., VOMS:/atlas/Role=production. The hack consists of explicitly
    # adding DENY: clauses to the VOview of VO:atlas, so it wouldn't match
    # VOMS:/atlas/Role=production.
    # The algorithm is pretty complicated.

    # 1: create a VOView for every FQAN in the ACBR.
    # 2: for every FQAN, if this is a 'top-level' VOView, i.e. either
    #      a) VO:foo or
    #      b) VOMS:/foo or even
    #      c) VOMS:/foo/Role=Null/Capability=Null
    #    then consider what other views there are for the same VO and add DENY clauses for them.
    for (@acl) {
      my $voms = $_;
      $voms =~ s/VO(MS)?://;
      # strip Role=Null and Capability=Null now
      $voms =~ s,/(Role|Capability)=Null,,ig;
      # convert any remaining '=' signs to '_'.
      my $localid = $voms;
      $localid =~ s/=/_/g;

      # retrieve the VO name
      my ($vo) = $voms =~ m,/?([^/]+),;
      print STDERR "VO: $vo\n" if $debug;
      my $defaultse = get_vo_param($vo, "DefaultSE");
      my $softwaredir = get_vo_param($vo, "SoftwareDir");
      print CE <<EOF;

dn: GlueVOViewLocalID=$localid,GlueCEUniqueID=$$n{hostname}:$port/$cetype-$$n{jobmanager}-$q,mds-vo-name=resource,o=grid
objectClass: GlueCETop
objectClass: GlueVOView
objectClass: GlueCEInfo
objectClass: GlueCEState
objectClass: GlueCEAccessControlBase
objectClass: GlueCEPolicy
objectClass: GlueKey
objectClass: GlueSchemaVersion
GlueVOViewLocalID: $localid
GlueCEStateRunningJobs: 0
GlueCEStateWaitingJobs: 444444
GlueCEStateTotalJobs: 0
GlueCEStateFreeJobSlots: 0
GlueCEStateEstimatedResponseTime: 2146660842
GlueCEStateWorstResponseTime: 2146660842
GlueCEInfoDefaultSE: $defaultse
GlueCEInfoApplicationDir: $softwaredir
GlueCEInfoDataDir: $$n{DataDir}
GlueChunkKey: GlueCEUniqueID=$$n{hostname}:$port/$cetype-$$n{jobmanager}-$q
GlueCEAccessControlBaseRule: $_
GlueSchemaVersionMajor: 1
GlueSchemaVersionMinor: 3
EOF
      # This tests for either no '/' or just a single '/' which indicates this is the
      # 'whole VO' view.
      if ($voms =~ m,^/?[^/]*$,) {
	# if $voms is just the VO name, make it canonical by prefixing a /.
	$voms =~ s,^(?!/),/,;
	# iterate over all ACLs again, scanning for sub-groups or roles within this VO.
	for my $denyacl (@acl) {
	  # perform the same manipulations we've done for localid
	  my $denyvoms = $denyacl;
	  $denyvoms =~ s/VO(MS)?://;
	  $denyvoms =~ s,/(Role|Capability)=Null,,ig;
	  $denyvoms =~ s,^(?!/),/,;
	  # Now see how $voms and $denyvoms are alike. Essentially, $denyvoms
	  # must be a prefix of $voms, but not exactly the same.
	  print STDERR "voms: $voms, denyvoms: $denyvoms, denyacl: $denyacl\n" if $debug;
	    if (0 == index($denyvoms, $voms) && length($denyvoms) > length($voms)) {
	      # add DENY clause here
	      print CE "GlueCEAccessControlBaseRule: DENY:$denyvoms\n";
	    }
	} # end search for VOMSes to deny
      } # end test for 'whole VO'
    } # ends loop over all the AccessControlBaseRule for this queue
  } # ends test for presence of AccessControlBaseRule for this queue
} # ends loop over queues for this CE


#   #==============
#   # GlueCESEBind
#   #==============

# This is all rather ugly, probably will have to be restructured
# See https://savannah.cern.ch/bugs/index.php?54530


my $ses = $ce{top}{SE_hosts} || "";

for my $q (split /\s+/, $queues) {
  print SEBIND <<EOF;

dn: GlueCESEBindGroupCEUniqueID=$$n{hostname}:$port/$cetype-$$n{jobmanager}-$q,mds-vo-name=resource,o=grid
objectClass: GlueGeneralTop
objectClass: GlueCESEBindGroup
objectClass: GlueSchemaVersion
GlueCESEBindGroupCEUniqueID: $$n{hostname}:$port/$cetype-$$n{jobmanager}-$q
EOF

  for my $se (split /\s+/, $ses) {
    print SEBIND "GlueCESEBindGroupSEUniqueID: $se\n";
  }
  print SEBIND <<EOF;
GlueSchemaVersionMajor: 1
GlueSchemaVersionMinor: 3
EOF


}

for my $se (split /\s+/, $ses) {
#  my $exportdir = $ce{$se}{exportdir} || "";
#  my $mountdir = $ce{$se}{mountdir} || $exportdir;
  my @mountinfo = ();
  for ($ce{$se}{exportdir}, $ce{$se}{mountdir}) {
    push @mountinfo, $_ if defined;
  }

#  my $accesspoint = $ce{$se}{exportdir} ? "$ce{$se}{exportdir},$ce{$se}{mountdir}" : "n.a";
  my $accesspoint = join(",", @mountinfo) ||  "n.a";
  for my $q (split /\s+/, $queues) {
    print SEBIND <<EOF

dn: GlueCESEBindSEUniqueID=$se,GlueCESEBindGroupCEUniqueID=$$n{hostname}:$port/$cetype-$$n{jobmanager}-$q,mds-vo-name=resource,o=grid
objectClass: GlueGeneralTop
objectClass: GlueCESEBind
objectClass: GlueSchemaVersion
GlueCESEBindSEUniqueID: $se
GlueCESEBindCEAccesspoint: $accesspoint
GlueCESEBindCEUniqueID: $$n{hostname}:$port/$cetype-$$n{jobmanager}-$q
GlueCESEBindMountInfo: $accesspoint
GlueCESEBindWeight: 0
GlueSchemaVersionMajor: 1
GlueSchemaVersionMinor: 3
EOF
  }
}
