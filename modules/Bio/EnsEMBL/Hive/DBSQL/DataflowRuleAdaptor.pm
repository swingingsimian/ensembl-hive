# Perl module for Bio::EnsEMBL::Hive::DBSQL::DataflowRuleAdaptor
#
# Date of creation: 22.03.2004
# Original Creator : Jessica Severin <jessica@ebi.ac.uk>
#
# Copyright EMBL-EBI 2004
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME
  Bio::EnsEMBL::Hive::DBSQL::DataflowRuleAdaptor 

=head1 SYNOPSIS
  $dataflowRuleAdaptor = $db_adaptor->get_DataflowRuleAdaptor;
  $dataflowRuleAdaptor = $dataflowRuleObj->adaptor;

=head1 DESCRIPTION
  Module to encapsulate all db access for persistent class DataflowRule.
  There should be just one per application and database connection.

=head1 CONTACT
  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX
  The rest of the documentation details each of the object methods.
  Internal methods are usually preceded with a _
  
=cut


# Let the code begin...


package Bio::EnsEMBL::Hive::DBSQL::DataflowRuleAdaptor;

use strict;
use Carp;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Hive::DataflowRule;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 fetch_from_analysis_job
  Args       : Bio::EnsEMBL::Hive::AnalysisJob
  Example    : my @rules = @{$ruleAdaptor->fetch_from_analysis_job($job)};
  Description: searches database for rules with given 'from' analysis
               returns all such rules in a list (by reference)
  Returntype : reference to list of Bio::EnsEMBL::Hive::DataflowRule objects
  Exceptions : none
  Caller     : ?
=cut
sub fetch_from_analysis_job
{
  my $self = shift;
  my $fromAnalysisJob = shift;
  my $rule;
  my @rules;
  
  $self->throw("arg is required\n") unless($fromAnalysisJob);
  $self->throw("arg must be a [Bio::EnsEMBL::Hive::AnalysisJob] not a $fromAnalysisJob")
    unless ($fromAnalysisJob->isa('Bio::EnsEMBL::Hive::AnalysisJob'));

  my $constraint = "r.from_analysis_id = '".$fromAnalysisJob->analysis_id."'"
                  ." AND r.branch_code=". $fromAnalysisJob->branch_code;

  return $self->_generic_fetch($constraint);
}


=head2 store
  Title   : store
  Usage   : $self->store( $rule );
  Function: Stores a rule in db
            Sets adaptor and dbID in DataflowRule
  Returns : -
  Args    : Bio::EnsEMBL::Pipeline::DataflowRule
=cut
sub store {
  my ( $self, $rule ) = @_;

  #print("\nDataflowRuleAdaptor->store()\n");
  my $dataflow_rule_id;
  
  my $sth = $self->prepare( q{INSERT ignore INTO dataflow_rule
       SET from_analysis_id = ?, to_analysis_url = ?, branch_code=? } );
  if($sth->execute($rule->from_analysis_id, $rule->to_analysis_url, $rule->branch_code)) {
    $dataflow_rule_id = $sth->{'mysql_insertid'};
    $sth->finish();
    $rule->dbID($dataflow_rule_id);
    #print("  stored with dbID = $dataflow_rule_id\n");
  } else {
    #print("  failed to execute -> already inserted -> need to get dbID\n");
    $sth->finish();
    $sth = $self->prepare(q{SELECT dataflow_rule_id FROM dataflow_rule WHERE
         from_analysis_id = ? AND to_analysis_url = ? } );
    $sth->execute($rule->from_analysis_id, $rule->to_analysis_url);
    $sth->bind_columns(\$dataflow_rule_id);
    if($sth->fetch()) {
      $rule->dbID($dataflow_rule_id);
    }
    $sth->finish;
  }
  #print("  dataflow_rule_id = '".$rule->dbID."'\n");
  $rule->adaptor( $self );
}


=head2 remove

  Title   : remove
  Usage   : $self->remove( $rule );
  Function: removes given object from database.
  Returns : -
  Args    : Bio::EnsEMBL::Pipeline::DataflowRule which must be persistent.
            ( dbID set )
=cut
sub remove {
  my ( $self, $rule ) = @_;

  my $dbID = $rule->dbID;
  if( !defined $dbID ) {
    $self->throw( "DataflowRuleAdaptor->remove called with non persistent DataflowRule" );
  }

  my $sth = $self->prepare("DELETE FROM dataflow_rule WHERE dataflow_rule_id = $dbID");
  $sth->execute;
}


sub create_rule {
  my ($self, $fromAnalysis, $toAnalysis, $branchCode) = @_;

  return unless($fromAnalysis and $toAnalysis);
  
  my $rule = Bio::EnsEMBL::Hive::DataflowRule->new();
  $rule->from_analysis($fromAnalysis);
  $rule->to_analysis($toAnalysis);
  $rule->branch_code($branchCode) if(defined($branchCode));
  
  $self->store($rule);
}

############################
#
# INTERNAL METHODS
# (pseudo subclass methods)
#
############################

#internal method used in multiple calls above to build objects from table data

sub _tables {
  my $self = shift;

  return (['dataflow_rule', 'r']);
}


sub _columns {
  my $self = shift;

  return qw (r.dataflow_rule_id
             r.from_analysis_id
             r.to_analysis_url
             r.branch_code
            );
}


sub _objs_from_sth {
  my ($self, $sth) = @_;
  my @rules = ();

  my ($dataflow_rule_id, $from_analysis_id, $to_analysis_url, $branch_code);
  $sth->bind_columns(\$dataflow_rule_id, \$from_analysis_id, \$to_analysis_url, \$branch_code);

  while ($sth->fetch()) {
    my $rule = Bio::EnsEMBL::Hive::DataflowRule->new;
    $rule->adaptor($self);
    $rule->dbID($dataflow_rule_id);
    $rule->from_analysis_id($from_analysis_id);
    $rule->to_analysis_url($to_analysis_url);
    $rule->branch_code($branch_code);
    push @rules, $rule;
  }
  return \@rules;
}


sub _default_where_clause {
  my $self = shift;
  return '';
}


sub _final_clause {
  my $self = shift;
  return '';
}

###############################################################################
#
# General access methods that could be moved
# into a superclass
#
###############################################################################

=head2 fetch_by_dbID
  Arg [1]    : int $id
               the unique database identifier for the feature to be obtained
  Example    : $feat = $adaptor->fetch_by_dbID(1234);
  Description: Returns the Member created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::Hive::DataflowRule
  Exceptions : thrown if $id is not defined
  Caller     : general
=cut
sub fetch_by_dbID{
  my ($self,$id) = @_;

  unless(defined $id) {
    $self->throw("fetch_by_dbID must have an id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${syn}.${name}_id = $id";

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
}


=head2 fetch_all
  Arg        : None
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :
=cut
sub fetch_all {
  my $self = shift;
  return $self->_generic_fetch();
}


=head2 _generic_fetch
  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
  Arg [2]    : (optional) string $logic_name
               the logic_name of the analysis of the features to obtain
  Example    : $fts = $a->_generic_fetch('contig_id in (1234, 1235)', 'Swall');
  Description: Performs a database fetch and returns feature objects in
               contig coordinates.
  Returntype : listref of Bio::EnsEMBL::SeqFeature in contig coordinates
  Exceptions : none
  Caller     : BaseFeatureAdaptor, ProxyDnaAlignFeatureAdaptor::_generic_fetch
=cut
sub _generic_fetch {
  my ($self, $constraint, $join) = @_;

  my @tables = $self->_tables;
  my $columns = join(', ', $self->_columns());

  if ($join) {
    foreach my $single_join (@{$join}) {
      my ($tablename, $condition, $extra_columns) = @{$single_join};
      if ($tablename && $condition) {
        push @tables, $tablename;

        if($constraint) {
          $constraint .= " AND $condition";
        } else {
          $constraint = " $condition";
        }
      }
      if ($extra_columns) {
        $columns .= ", " . join(', ', @{$extra_columns});
      }
    }
  }

  #construct a nice table string like 'table1 t1, table2 t2'
  my $tablenames = join(', ', map({ join(' ', @$_) } @tables));

  my $sql = "SELECT $columns FROM $tablenames";

  my $default_where = $self->_default_where_clause;
  my $final_clause = $self->_final_clause;

  #append a where clause if it was defined
  if($constraint) {
    $sql .= " WHERE $constraint ";
    if($default_where) {
      $sql .= " AND $default_where ";
    }
  } elsif($default_where) {
    $sql .= " WHERE $default_where ";
  }

  #append additional clauses which may have been defined
  $sql .= " $final_clause";

  my $sth = $self->prepare($sql);
  $sth->execute;

#  print STDERR $sql,"\n";

  return $self->_objs_from_sth($sth);
}


1;
