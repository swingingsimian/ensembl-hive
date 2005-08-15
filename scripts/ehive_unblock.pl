#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Hive;

my ($help, $url);

GetOptions('help'           => \$help,
           'url=s'          => \$url,
          );

if ($help) { usage(); }

my $job = Bio::EnsEMBL::Hive::URLFactory->fetch($url);
die("Unable to fecth job via url $url\n") unless($job);

$job->print_job;
$job->update_status('READY');

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "ehive_unblock.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -url <url string>      : url defining hive job\n";
  print "ehive_unblock.pl v1.7\n";
  
  exit(1);  
}

