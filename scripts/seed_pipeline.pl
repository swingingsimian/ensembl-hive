#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;

use Bio::EnsEMBL::Hive::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor;
use Bio::EnsEMBL::Hive::Utils ('destringify', 'stringify');

my ($reg_conf, $reg_alias, $url, $analysis_id, $logic_name, $input_id);


GetOptions(
            # connect to the database:
        'reg_conf|regfile=s'    => \$reg_conf,
        'reg_alias|regname=s'   => \$reg_alias,
        'url=s'                 => \$url,

            # identify the analysis:
        'analysis_id=i'         => \$analysis_id,
        'logic_name=s'          => \$logic_name,

            # specify the input_id (as a string):
        'input_id=s'            => \$input_id,
);

my $hive_dba;
if($reg_conf and $reg_alias) {
    Bio::EnsEMBL::Registry->load_all($reg_conf);
    $hive_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($reg_alias, 'hive');
} elsif($url) {
    $hive_dba = Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(-url => $url);
} else {
    die "Connection parameters (url or reg_conf+reg_alias) need to be specified";
}

my $analysis_adaptor = $hive_dba->get_AnalysisAdaptor;
my $analysis; 
if($logic_name) {
    $analysis = $analysis_adaptor->fetch_by_logic_name( $logic_name )
        or die "Could not fetch analysis '$logic_name'";
} else {
    unless($analysis_id) {
        $analysis_id = 1;
        warn "Neither -logic_name nor -analysis_id was set, assuming analysis_id='$analysis_id'\n";
    }
    $analysis = $analysis_adaptor->fetch_by_dbID( $analysis_id )
        or die "Could not fetch analysis with dbID='$analysis_id'";
}

unless($input_id) {
    $input_id = '{}';
    warn "Since -input_id has not been set, assuming input_id='$input_id'\n";
}

    # Make sure all job creations undergo re-stringification
    # to avoid alternative "spellings" of the same input_id hash:
$input_id = stringify( destringify( $input_id ) ); 

Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
    -analysis       => $analysis,
    -input_id       => $input_id,
    -prev_job_id    => undef,       # this job has been created by the initialization script, not by another job
) or die "Could not create job '$input_id' (it could have been there already)\n";

warn "Job '$input_id' in analysis '".$analysis->logic_name."'(".$analysis->dbID.") has been created\n";

1;
