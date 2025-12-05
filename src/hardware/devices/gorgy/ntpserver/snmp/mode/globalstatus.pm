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

package hardware::devices::gorgy::ntpserver::snmp::mode::globalstatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);

sub custom_sync_status_output {
    my ($self, %options) = @_;
    
    my $msg = sprintf(
        "Synchronization: %s [source: %s]",
        $self->{result_values}->{sync_status},
        $self->{result_values}->{sync_source}
    );
    return $msg;
}

sub custom_timebase_status_output {
    my ($self, %options) = @_;
    
    my $msg = 'Time base: ' . $self->{result_values}->{timebase_status};
    return $msg;
}

sub custom_autonomy_output {
    my ($self, %options) = @_;
    
    return 'Autonomy: ' . $self->{result_values}->{autonomy_status};
}

sub custom_external_sync_output {
    my ($self, %options) = @_;
    
    my %ext_sync_map = (
        0 => 'not synchronized',
        1 => 'synchronized',
        2 => 'not applicable',
        3 => 'never synchronized'
    );
    
    my $status = defined($ext_sync_map{$self->{result_values}->{external_sync}}) ? 
        $ext_sync_map{$self->{result_values}->{external_sync}} : 'unknown';
    
    return 'External synchronization: ' . $status;
}

sub custom_status_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{$options{extra_options}->{label_ref}} = $options{new_datas}->{$self->{instance} . '_' . $options{extra_options}->{label_ref}};
    $self->{result_values}->{label} = $options{extra_options}->{label_ref};
    return 0;
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ' }
    ];
    
    $self->{maps_counters}->{global} = [
        { label => 'sync-status', threshold => 0, set => {
                key_values => [ { name => 'sync_status' }, { name => 'sync_source' } ],
                closure_custom_output => $self->can('custom_sync_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'timebase-status', threshold => 0, set => {
                key_values => [ { name => 'timebase_status' } ],
                closure_custom_calc => $self->can('custom_status_calc'), closure_custom_calc_extra_options => { label_ref => 'timebase_status' },
                closure_custom_output => $self->can('custom_timebase_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'external-sync', threshold => 0, set => {
                key_values => [ { name => 'external_sync' } ],
                closure_custom_output => $self->can('custom_external_sync_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'autonomy-status', threshold => 0, set => {
                key_values => [ { name => 'autonomy_status' } ],
                closure_custom_output => $self->can('custom_autonomy_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'sync-lost-duration', set => {
                key_values => [ { name => 'sync_lost_duration' } ],
                output_template => 'Time since sync lost: %s s',
                perfdatas => [
                    { label => 'sync_lost_duration', value => 'sync_lost_duration', template => '%s', 
                      min => 0, unit => 's' },
                ],
            }
        },
        { label => 'ntp-requests', set => {
                key_values => [ { name => 'ntp_requests', diff => 1 } ],
                output_template => 'NTP requests: %s',
                perfdatas => [
                    { label => 'ntp_requests', value => 'ntp_requests', template => '%s', 
                      min => 0 },
                ],
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        'warning-sync-status:s'      => { name => 'warning_sync_status', default => '%{sync_status} =~ /Running with autonomy|Free running/i' },
        'critical-sync-status:s'     => { name => 'critical_sync_status', default => '%{sync_status} =~ /Server locked|Never synchronized|Server not synchronized|Output card disabled/i' },
        'warning-timebase-status:s'  => { name => 'warning_timebase_status', default => '%{timebase_status} =~ /Warming up|Precision >|us </i' },
        'critical-timebase-status:s' => { name => 'critical_timebase_status', default => '%{timebase_status} =~ /^(XO|Error|Unknown)$/i' },
        'warning-external-sync:s'    => { name => 'warning_external_sync', default => '%{external_sync} == 0' },
        'critical-external-sync:s'   => { name => 'critical_external_sync', default => '%{external_sync} == 3' },
        'warning-autonomy-status:s'  => { name => 'warning_autonomy_status', default => '%{autonomy_status} =~ /Remaining Autonomy/i' },
        'critical-autonomy-status:s' => { name => 'critical_autonomy_status', default => '' },
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => [
        'warning_sync_status', 'critical_sync_status',
        'warning_timebase_status', 'critical_timebase_status',
        'warning_external_sync', 'critical_external_sync',
        'warning_autonomy_status', 'critical_autonomy_status'
    ]);
}

# timeBaseState values:
#   XO Warming up...
#   XO OK
#   TCXO
#   TCXO Precision > 25usec
#   2usec < TCXO Precision < 25usec
#   TCXO Precision < 2usec
#   OCXO Warming up...
#   OCXO Precision > 20usec
#   1usec < OCXO Precision < 20usec
#   OCXO Precision < 1usec
#   XO

# currentSyncState values:
#   Server locked
#   Free running
#   Never synchronized
#   Server synchronized
#   Running with autonomy
#   Server not synchronized
#   Computing synchronization
#   Output card disabled

# currentSyncSource values:
#   no_sync, sdib, gnss, irig, ntp, ptp, dcf, tdf, freq, pps, ascii

# externallySynchronized values:
#   0: false, 1: true, 2: notapplicable, 3: neversync

# autonomous values:
#   0: false, 1: true, 2: notapplicable

my $mapping = {
    currentSyncState         => { oid => '.1.3.6.1.4.1.8955.1.8.1.10' },
    currentSyncSource        => { oid => '.1.3.6.1.4.1.8955.1.8.1.11' },
    timeBaseState            => { oid => '.1.3.6.1.4.1.8955.1.8.1.12' },
    syncLostDuration         => { oid => '.1.3.6.1.4.1.8955.1.8.1.13' },
    externallySynchronized   => { oid => '.1.3.6.1.4.1.8955.1.8.1.14' },
    autonomous               => { oid => '.1.3.6.1.4.1.8955.1.8.1.15' },
    autonomy                 => { oid => '.1.3.6.1.4.1.8955.1.8.1.16' },
    syncAlarm                => { oid => '.1.3.6.1.4.1.8955.1.8.1.8' },
    ntpRequestsNumber        => { oid => '.1.3.6.1.4.1.8955.1.8.2.3' },
};

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_leef(
        oids => [
            $mapping->{currentSyncState}->{oid} . '.0',
            $mapping->{currentSyncSource}->{oid} . '.0',
            $mapping->{timeBaseState}->{oid} . '.0',
            $mapping->{syncLostDuration}->{oid} . '.0',
            $mapping->{externallySynchronized}->{oid} . '.0',
            $mapping->{autonomous}->{oid} . '.0',
            $mapping->{autonomy}->{oid} . '.0',
            $mapping->{syncAlarm}->{oid} . '.0',
            $mapping->{ntpRequestsNumber}->{oid} . '.0'
        ],
        nothing_quit => 1
    );
    my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => '0');
    $self->{global} = {
        sync_status        => defined($result->{currentSyncState}) ? $result->{currentSyncState} : 'unknown',
        sync_source        => defined($result->{currentSyncSource}) ? $result->{currentSyncSource} : 'unknown',
        timebase_status    => defined($result->{timeBaseState}) ? $result->{timeBaseState} : 'unknown',
        sync_lost_duration => defined($result->{syncLostDuration}) ? $result->{syncLostDuration} : 0,
        external_sync      => defined($result->{externallySynchronized}) ? $result->{externallySynchronized} : 2,
        autonomy_status    => defined($result->{autonomy}) ? $result->{autonomy} : 'Not available',
        ntp_requests       => defined($result->{ntpRequestsNumber}) ? $result->{ntpRequestsNumber} : 0
    };

    $self->{cache_name} = "gorgy_ntpserver_" . $self->{mode} . '_' . $options{snmp}->get_hostname()  . '_' . $options{snmp}->get_port() . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check ntp server status.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^sync-status$'

=item B<--warning-sync-status>

Define the conditions to match for the status to be WARNING (default: '%{sync_status} =~ /Running with autonomy|Free running/i').
You can use the following variables: %{sync_status}

=item B<--critical-sync-status>

Define the conditions to match for the status to be CRITICAL (default: '%{sync_status} =~ /Server locked|Never synchronized|Server not synchronized/i').
You can use the following variables: %{sync_status}

=item B<--warning-timebase-status>

Define the conditions to match for the status to be WARNING (default: '%{timebase_status} =~ /^(?!(XO|XO OK|TCXO Precision < 2usec|OCXO Precision < 1usec)$)/i').
You can use the following variables: %{timebase_status}

=item B<--critical-timebase-status>

Define the conditions to match for the status to be CRITICAL (default: '%{timebase_status} =~ /^XO$/i').
You can use the following variables: %{timebase_status}

=item B<--warning-*>

Warning threshold.
Can be: 'ntp-requests'.

=item B<--critical-*>

Critical threshold.
Can be: 'ntp-requests'.

=back

=cut
