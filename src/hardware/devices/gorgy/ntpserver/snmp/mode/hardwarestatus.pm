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

package hardware::devices::gorgy::ntpserver::snmp::mode::hardwarestatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);

sub custom_temperature_output {
    my ($self, %options) = @_;
    
    return sprintf("Temperature: %s", $self->{result_values}->{temperature});
}

sub custom_power_status_output {
    my ($self, %options) = @_;
    
    my $msg = 'Power supply: ';
    my $flags = $self->{result_values}->{power_flags};
    
    if ($flags eq '0x00' || $flags eq '0') {
        $msg .= 'all sources OK';
    } elsif ($flags eq '0x01' || $flags eq '1') {
        $msg .= 'primary source failure';
    } elsif ($flags eq '0x02' || $flags eq '2') {
        $msg .= 'secondary source failure';
    } elsif ($flags eq '0x03' || $flags eq '3') {
        $msg .= 'running on battery';
    } else {
        $msg .= 'flags=' . $flags;
    }
    
    return $msg;
}

sub custom_rb_status_output {
    my ($self, %options) = @_;
    
    return sprintf("Atomic oscillator: %s", $self->{result_values}->{rb_state});
}

sub custom_sync_alarm_output {
    my ($self, %options) = @_;
    
    my $status = $self->{result_values}->{sync_alarm} == 1 ? 'ALARM - no sync and no autonomy' : 'OK';
    return sprintf("Sync alarm: %s", $status);
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'hardware', type => 0, message_separator => ' - ' }
    ];
    
    $self->{maps_counters}->{hardware} = [
        { label => 'temperature', threshold => 0, set => {
                key_values => [ { name => 'temperature' } ],
                closure_custom_output => $self->can('custom_temperature_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'power-status', threshold => 0, set => {
                key_values => [ { name => 'power_flags' } ],
                closure_custom_output => $self->can('custom_power_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'rb-status', threshold => 0, set => {
                key_values => [ { name => 'rb_state' } ],
                closure_custom_output => $self->can('custom_rb_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'sync-alarm', threshold => 0, set => {
                key_values => [ { name => 'sync_alarm' } ],
                closure_custom_output => $self->can('custom_sync_alarm_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'battery-autonomy', set => {
                key_values => [ { name => 'battery_autonomy' } ],
                output_template => 'Battery autonomy: %s s',
                perfdatas => [
                    { label => 'battery_autonomy', value => 'battery_autonomy', template => '%s',
                      min => 0, unit => 's' },
                ],
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        'warning-temperature:s'   => { name => 'warning_temperature', default => '%{temperature} =~ /Not available/i' },
        'critical-temperature:s'  => { name => 'critical_temperature', default => '' },
        'warning-power-status:s'  => { name => 'warning_power_status', default => '%{power_flags} =~ /^(1|2)$/' },
        'critical-power-status:s' => { name => 'critical_power_status', default => '%{power_flags} =~ /^3$/' },
        'warning-rb-status:s'     => { name => 'warning_rb_status', default => '%{rb_state} =~ /Warming up|Reference unstable|Unknown/i' },
        'critical-rb-status:s'    => { name => 'critical_rb_status', default => '%{rb_state} =~ /Error/i' },
        'warning-sync-alarm:s'    => { name => 'warning_sync_alarm', default => '' },
        'critical-sync-alarm:s'   => { name => 'critical_sync_alarm', default => '%{sync_alarm} == 1' },
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => [
        'warning_temperature', 'critical_temperature',
        'warning_power_status', 'critical_power_status',
        'warning_rb_status', 'critical_rb_status',
        'warning_sync_alarm', 'critical_sync_alarm'
    ]);
}

my $mapping = {
    syncAlarm        => { oid => '.1.3.6.1.4.1.8955.1.8.1.8' },
    internalTemp     => { oid => '.1.3.6.1.4.1.8955.1.8.1.17' },
    rbState          => { oid => '.1.3.6.1.4.1.8955.1.8.1.18' },
    powerDownFlags   => { oid => '.1.3.6.1.4.1.8955.1.8.1.20' },
    batteryAutonomy  => { oid => '.1.3.6.1.4.1.8955.1.8.1.21' },
};

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_leef(
        oids => [
            $mapping->{syncAlarm}->{oid} . '.0',
            $mapping->{internalTemp}->{oid} . '.0',
            $mapping->{rbState}->{oid} . '.0',
            $mapping->{powerDownFlags}->{oid} . '.0',
            $mapping->{batteryAutonomy}->{oid} . '.0'
        ]
    );
    my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => '0');

    $self->{hardware} = {
        temperature      => defined($result->{internalTemp}) ? $result->{internalTemp} : 'Not available',
        power_flags      => defined($result->{powerDownFlags}) ? $result->{powerDownFlags} : '0',
        rb_state         => defined($result->{rbState}) ? $result->{rbState} : 'N/A',
        sync_alarm       => defined($result->{syncAlarm}) ? $result->{syncAlarm} : 0,
        battery_autonomy => defined($result->{batteryAutonomy}) ? $result->{batteryAutonomy} : 0
    };
}

1;

__END__

=head1 MODE

Check hardware status (temperature, power supply, battery, atomic oscillator).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^temperature$'

=item B<--warning-temperature>

Define the conditions to match for the status to be WARNING (default: '%{temperature} =~ /Not available/i').
You can use the following variables: %{temperature}

=item B<--critical-temperature>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{temperature}

=item B<--warning-power-status>

Define the conditions to match for the status to be WARNING (default: '%{power_flags} =~ /^(1|2)$/').
Power flags: 0=all OK, 1=primary failure, 2=secondary failure, 3=on battery.
You can use the following variables: %{power_flags}

=item B<--critical-power-status>

Define the conditions to match for the status to be CRITICAL (default: '%{power_flags} =~ /^3$/').
You can use the following variables: %{power_flags}

=item B<--warning-rb-status>

Define the conditions to match for the status to be WARNING (default: '%{rb_state} =~ /Warming up|Reference unstable|Unknown/i').
You can use the following variables: %{rb_state}

=item B<--critical-rb-status>

Define the conditions to match for the status to be CRITICAL (default: '%{rb_state} =~ /Error/i').
You can use the following variables: %{rb_state}

=item B<--warning-sync-alarm>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{sync_alarm}

=item B<--critical-sync-alarm>

Define the conditions to match for the status to be CRITICAL (default: '%{sync_alarm} == 1').
You can use the following variables: %{sync_alarm}

=item B<--warning-*>

Warning threshold.
Can be: 'battery-autonomy'.

=item B<--critical-*>

Critical threshold.
Can be: 'battery-autonomy'.

=back

=cut
