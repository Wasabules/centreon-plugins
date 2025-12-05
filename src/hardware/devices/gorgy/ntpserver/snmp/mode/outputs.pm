#
# Copyright 2024 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package hardware::devices::gorgy::ntpserver::snmp::mode::outputs;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);

sub custom_output_status_output {
    my ($self, %options) = @_;
    
    my $msg = sprintf(
        "Output card '%s' [addr:%s]: %s outputs",
        $self->{result_values}->{output_desc},
        $self->{result_values}->{output_addr},
        $self->{result_values}->{output_num}
    );
    
    return $msg;
}

sub custom_datel_status_output {
    my ($self, %options) = @_;
    
    my $unsync = $self->{result_values}->{datel_unsync};
    my $go = $self->{result_values}->{datel_go};
    my $cnt = $self->{result_values}->{datel_unsync_cnt};
    
    my $status = 'synchronized';
    $status = 'unsynchronized' if ($unsync == 1);
    $status = 'no-go' if ($go == 0);
    
    return sprintf(
        "Datel status: %s (unsync:%d, go:%d, cnt:%d)",
        $status, $unsync, $go, $cnt
    );
}

sub prefix_output_output {
    my ($self, %options) = @_;
    
    return "Output card '" . $options{instance_value}->{output_desc} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'outputs', type => 1, cb_prefix_output => 'prefix_output_output', message_multiple => 'All output cards are ok' }
    ];
    
    $self->{maps_counters}->{outputs} = [
        { label => 'output-status', threshold => 0, set => {
                key_values => [ { name => 'output_desc' }, { name => 'output_addr' }, { name => 'output_num' } ],
                closure_custom_output => $self->can('custom_output_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'datel-status', threshold => 0, set => {
                key_values => [ { name => 'datel_unsync' }, { name => 'datel_go' }, { name => 'datel_unsync_cnt' }, { name => 'output_desc' } ],
                closure_custom_output => $self->can('custom_datel_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        'filter-output:s'        => { name => 'filter_output' },
        'warning-output-status:s'=> { name => 'warning_output_status', default => '' },
        'critical-output-status:s'=> { name => 'critical_output_status', default => '' },
        'warning-datel-status:s' => { name => 'warning_datel_status', default => '%{datel_unsync} == 1' },
        'critical-datel-status:s'=> { name => 'critical_datel_status', default => '%{datel_go} == 0' },
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => [
        'warning_output_status', 'critical_output_status',
        'warning_datel_status', 'critical_datel_status'
    ]);
}

my $mapping = {
    outputCardDescription => { oid => '.1.3.6.1.4.1.8955.1.8.4.1.1' },
    outputCardAddress     => { oid => '.1.3.6.1.4.1.8955.1.8.4.1.2' },
    outputOutNumber       => { oid => '.1.3.6.1.4.1.8955.1.8.4.1.4' },
    outputDatelUnsync     => { oid => '.1.3.6.1.4.1.8955.1.8.4.1.5' },
    outputDatelUnsyncCnt  => { oid => '.1.3.6.1.4.1.8955.1.8.4.1.6' },
    outputDatelGo         => { oid => '.1.3.6.1.4.1.8955.1.8.4.1.7' },
};

my $oid_outputEntry = '.1.3.6.1.4.1.8955.1.8.4.1';

sub manage_selection {
    my ($self, %options) = @_;

    $self->{outputs} = {};
    
    my $snmp_result = $options{snmp}->get_table(
        oid => $oid_outputEntry,
        start => $mapping->{outputCardDescription}->{oid},
        end => $mapping->{outputDatelGo}->{oid}
    );

    if (!defined($snmp_result) || scalar(keys %{$snmp_result}) == 0) {
        $self->{output}->add_option_msg(short_msg => "No output cards found (may be normal if device has no output cards).");
        $self->{output}->option_exit();
    }

    foreach my $oid (keys %{$snmp_result}) {
        next if ($oid !~ /^$mapping->{outputCardDescription}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => $instance);

        if (defined($self->{option_results}->{filter_output}) && $self->{option_results}->{filter_output} ne '' &&
            $result->{outputCardDescription} !~ /$self->{option_results}->{filter_output}/) {
            $self->{output}->output_add(long_msg => "skipping output '" . $result->{outputCardDescription} . "'.", debug => 1);
            next;
        }

        $self->{outputs}->{$instance} = {
            output_desc        => $result->{outputCardDescription},
            output_addr        => $result->{outputCardAddress},
            output_num         => $result->{outputOutNumber},
            datel_unsync       => defined($result->{outputDatelUnsync}) ? $result->{outputDatelUnsync} : 0,
            datel_unsync_cnt   => defined($result->{outputDatelUnsyncCnt}) ? $result->{outputDatelUnsyncCnt} : 0,
            datel_go           => defined($result->{outputDatelGo}) ? $result->{outputDatelGo} : 1,
        };
    }
    
    if (scalar(keys %{$self->{outputs}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No output cards found (may be normal if device has no output cards).");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check output cards status.

=over 8

=item B<--filter-output>

Filter outputs by description (can be a regexp).

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^output-status$'

=item B<--warning-output-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{output_desc}, %{output_addr}, %{output_num}

=item B<--critical-output-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{output_desc}, %{output_addr}, %{output_num}

=item B<--warning-datel-status>

Define the conditions to match for the status to be WARNING (default: '%{datel_unsync} == 1').
You can use the following variables: %{datel_unsync}, %{datel_go}, %{datel_unsync_cnt}, %{output_desc}

=item B<--critical-datel-status>

Define the conditions to match for the status to be CRITICAL (default: '%{datel_go} == 0').
You can use the following variables: %{datel_unsync}, %{datel_go}, %{datel_unsync_cnt}, %{output_desc}

=back

=cut
