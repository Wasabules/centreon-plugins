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

package hardware::devices::gorgy::ntpserver::snmp::mode::ntpserver;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);

sub custom_stratum_output {
    my ($self, %options) = @_;
    
    return sprintf("Stratum level: %s", $self->{result_values}->{stratum});
}

sub custom_leap_indicator_output {
    my ($self, %options) = @_;
    
    my %leap_map = (
        0 => 'no warning',
        1 => 'last minute has 61 seconds',
        2 => 'last minute has 59 seconds',
        3 => 'alarm (clock not synchronized)'
    );
    
    my $li_desc = defined($leap_map{$self->{result_values}->{leap_indicator}}) ? 
        $leap_map{$self->{result_values}->{leap_indicator}} : 'unknown';
    
    return sprintf("Leap indicator: %s (%s)", $self->{result_values}->{leap_indicator}, $li_desc);
}

sub custom_auth_policy_output {
    my ($self, %options) = @_;
    
    return sprintf("Authentication policy: %s", $self->{result_values}->{auth_policy});
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'ntp', type => 0, message_separator => ' - ' }
    ];
    
    $self->{maps_counters}->{ntp} = [
        { label => 'stratum', threshold => 0, set => {
                key_values => [ { name => 'stratum' } ],
                closure_custom_output => $self->can('custom_stratum_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'leap-indicator', threshold => 0, set => {
                key_values => [ { name => 'leap_indicator' } ],
                closure_custom_output => $self->can('custom_leap_indicator_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'auth-policy', threshold => 0, set => {
                key_values => [ { name => 'auth_policy' } ],
                closure_custom_output => $self->can('custom_auth_policy_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
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
        { label => 'rejected-requests', set => {
                key_values => [ { name => 'rejected_requests', diff => 1 } ],
                output_template => 'Rejected requests: %s',
                perfdatas => [
                    { label => 'rejected_requests', value => 'rejected_requests', template => '%s',
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
        'warning-stratum:s'       => { name => 'warning_stratum', default => '%{stratum} >= 10' },
        'critical-stratum:s'      => { name => 'critical_stratum', default => '%{stratum} == 16' },
        'warning-leap-indicator:s'=> { name => 'warning_leap_indicator', default => '%{leap_indicator} =~ /^(1|2)$/' },
        'critical-leap-indicator:s'=> { name => 'critical_leap_indicator', default => '%{leap_indicator} == 3' },
        'warning-auth-policy:s'   => { name => 'warning_auth_policy', default => '' },
        'critical-auth-policy:s'  => { name => 'critical_auth_policy', default => '' },
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => [
        'warning_stratum', 'critical_stratum',
        'warning_leap_indicator', 'critical_leap_indicator',
        'warning_auth_policy', 'critical_auth_policy'
    ]);
}

my $mapping = {
    stratumLevel            => { oid => '.1.3.6.1.4.1.8955.1.8.2.1' },
    leapIndicatorValue      => { oid => '.1.3.6.1.4.1.8955.1.8.2.2' },
    ntpRequestsNumber       => { oid => '.1.3.6.1.4.1.8955.1.8.2.3' },
    rejectedRequestsNumber  => { oid => '.1.3.6.1.4.1.8955.1.8.2.4' },
    authenticationPolicy    => { oid => '.1.3.6.1.4.1.8955.1.8.2.5' },
    md5AuthenticationKeys   => { oid => '.1.3.6.1.4.1.8955.1.8.2.6' },
    syncLostStratumLevel    => { oid => '.1.3.6.1.4.1.8955.1.8.2.9' },
    syncLostLeapIndicator   => { oid => '.1.3.6.1.4.1.8955.1.8.2.10' },
};

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_leef(
        oids => [
            $mapping->{stratumLevel}->{oid} . '.0',
            $mapping->{leapIndicatorValue}->{oid} . '.0',
            $mapping->{ntpRequestsNumber}->{oid} . '.0',
            $mapping->{rejectedRequestsNumber}->{oid} . '.0',
            $mapping->{authenticationPolicy}->{oid} . '.0',
            $mapping->{md5AuthenticationKeys}->{oid} . '.0',
            $mapping->{syncLostStratumLevel}->{oid} . '.0',
            $mapping->{syncLostLeapIndicator}->{oid} . '.0'
        ],
        nothing_quit => 1
    );
    my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => '0');

    $self->{ntp} = {
        stratum             => defined($result->{stratumLevel}) ? $result->{stratumLevel} : 16,
        leap_indicator      => defined($result->{leapIndicatorValue}) ? $result->{leapIndicatorValue} : 3,
        ntp_requests        => defined($result->{ntpRequestsNumber}) ? $result->{ntpRequestsNumber} : 0,
        rejected_requests   => defined($result->{rejectedRequestsNumber}) ? $result->{rejectedRequestsNumber} : 0,
        auth_policy         => defined($result->{authenticationPolicy}) ? $result->{authenticationPolicy} : 'Unknown',
    };

    $self->{cache_name} = "gorgy_ntpserver_" . $self->{mode} . '_' . $options{snmp}->get_hostname() . '_' . $options{snmp}->get_port() . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check NTP server statistics (stratum, leap indicator, requests, authentication).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^stratum$'

=item B<--warning-stratum>

Define the conditions to match for the status to be WARNING (default: '%{stratum} >= 10').
You can use the following variables: %{stratum}

=item B<--critical-stratum>

Define the conditions to match for the status to be CRITICAL (default: '%{stratum} == 16').
You can use the following variables: %{stratum}

=item B<--warning-leap-indicator>

Define the conditions to match for the status to be WARNING (default: '%{leap_indicator} =~ /^(1|2)$/').
Leap indicator values: 0=no warning, 1=last minute 61s, 2=last minute 59s, 3=alarm.
You can use the following variables: %{leap_indicator}

=item B<--critical-leap-indicator>

Define the conditions to match for the status to be CRITICAL (default: '%{leap_indicator} == 3').
You can use the following variables: %{leap_indicator}

=item B<--warning-auth-policy>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{auth_policy}

=item B<--critical-auth-policy>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{auth_policy}

=item B<--warning-*>

Warning threshold.
Can be: 'ntp-requests', 'rejected-requests'.

=item B<--critical-*>

Critical threshold.
Can be: 'ntp-requests', 'rejected-requests'.

=back

=cut
