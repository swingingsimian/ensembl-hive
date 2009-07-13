# A Meadow is an abstract interface for one of several implementations of Workers' process manager.
#
# A Meadow knows how to check&change the actual status of Workers

package Bio::EnsEMBL::Hive::Meadow;

use strict;

sub new {
    my $class = shift @_;

    return bless { @_ }, $class;
}

sub type { # should return 'LOCAL' or 'LSF'
    return (reverse split(/::/, ref(shift @_)))[0];
}

sub responsible_for_worker {
    my ($self, $worker) = @_;

    return $worker->beekeeper() eq $self->type();
}

sub check_worker_is_alive {
    my ($self, $worker) = @_;

    die "Please use a derived method";
}

sub kill_worker {
    my ($self, $worker) = @_;

    die "Please use a derived method";
}

# --------------[(combinable) means of adjusting the number of submitted workers]----------------------

sub total_running_workers_limit { # if set and ->can('count_running_workers'),
                                  # provides a cut-off on the number of workers being submitted
    my $self = shift @_;

    if(scalar(@_)) { # new value is being set (which can be undef)
        $self->{'_total_running_workers_limit'} = shift @_;
    }
    return $self->{'_total_running_workers_limit'};
}

sub pending_adjust { # if set and ->can('count_pending_workers'),
                     # provides a cut-off on the number of workers being submitted
    my $self = shift @_;

    if(scalar(@_)) { # new value is being set (which can be undef)
        $self->{'_pending_adjust'} = shift @_;
    }
    return $self->{'_pending_adjust'};
}

sub submitted_workers_limit { # if set, provides a cut-off on the number of workers being submitted
    my $self = shift @_;

    if(scalar(@_)) { # new value is being set (which can be undef)
        $self->{'_submitted_workers_limit'} = shift @_;
    }
    return $self->{'_submitted_workers_limit'};
}

sub limit_workers {
    my ($self, $worker_count, $hive_name) = @_;

    if($self->can('count_pending_workers') and $self->pending_adjust()) {
        my $pending_count = $self->count_pending_workers($hive_name);

        $worker_count -= $pending_count;
    }

    if(defined(my $submit_limit = $self->submitted_workers_limit)) {
        if($submit_limit < $worker_count) {

            $worker_count = $submit_limit;
        }
    }

    if($self->can('count_running_workers') and defined(my $total_limit = $self->total_running_workers_limit)) {
        my $available_slots = $total_limit - $self->count_running_workers();
        if($available_slots < $worker_count) {

            $worker_count = $available_slots;
        }
    }

    $worker_count = 0 if ($worker_count<0);

    return $worker_count;
}

1;
