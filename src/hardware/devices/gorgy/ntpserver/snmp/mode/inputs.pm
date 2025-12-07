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

package hardware::devices::gorgy::ntpserver::snmp::mode::inputs;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);

sub custom_input_status_output {
    my ($self, %options) = @_;
    
    my $msg = sprintf(
        "Input '%s' [%s]: %s",
        $self->{result_values}->{input_desc},
        $self->{result_values}->{input_addr},
        $self->{result_values}->{input_state}
    );
    
    if (defined($self->{result_values}->{is_driving}) && $self->{result_values}->{is_driving} eq '1') {
        $msg .= ' [DRIVING]';
    }
    
    return $msg;
}

sub custom_satellites_output {
    my ($self, %options) = @_;
    
    my @sats;
    push @sats, "GPS:" . $self->{result_values}->{gps_sat} if $self->{result_values}->{gps_sat} ne 'N/A';
    push @sats, "GLO:" . $self->{result_values}->{glonass_sat} if $self->{result_values}->{glonass_sat} ne 'N/A';
    push @sats, "GAL:" . $self->{result_values}->{galileo_sat} if $self->{result_values}->{galileo_sat} ne 'N/A';
    push @sats, "BEI:" . $self->{result_values}->{beidou_sat} if $self->{result_values}->{beidou_sat} ne 'N/A';
    
    return 'Satellites: ' . (@sats ? join(', ', @sats) : 'N/A');
}

sub prefix_input_output {
    my ($self, %options) = @_;
    
    return "Input '" . $options{instance_value}->{input_desc} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'inputs', type => 1, cb_prefix_output => 'prefix_input_output', message_multiple => 'All time inputs are ok' }
    ];
    
    $self->{maps_counters}->{inputs} = [
        { label => 'input-status', threshold => 0, set => {
                key_values => [ { name => 'input_state' }, { name => 'input_desc' }, { name => 'input_addr' }, { name => 'is_driving' }, { name => 'is_disabled' } ],
                closure_custom_output => $self->can('custom_input_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'satellites', threshold => 0, set => {
                key_values => [ { name => 'gps_sat' }, { name => 'glonass_sat' }, { name => 'galileo_sat' }, { name => 'beidou_sat' } ],
                closure_custom_output => $self->can('custom_satellites_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'pps-offset-tb', set => {
                key_values => [ { name => 'pps_offset_tb' }, { name => 'input_desc' } ],
                output_template => 'PPS offset TB: %s ns',
                perfdatas => [
                    { label => 'pps_offset_tb', value => 'pps_offset_tb', template => '%d',
                      unit => 'ns', label_extra_instance => 1, instance_use => 'input_desc' },
                ],
            }
        },
        { label => 'pps-offset-vclock', set => {
                key_values => [ { name => 'pps_offset_vclock' }, { name => 'input_desc' } ],
                output_template => 'PPS offset vClock: %s ns',
                perfdatas => [
                    { label => 'pps_offset_vclock', value => 'pps_offset_vclock', template => '%d',
                      unit => 'ns', label_extra_instance => 1, instance_use => 'input_desc' },
                ],
            }
        },
        { label => 'second-offset', set => {
                key_values => [ { name => 'second_offset' }, { name => 'input_desc' } ],
                output_template => 'Second offset: %s s',
                perfdatas => [
                    { label => 'second_offset', value => 'second_offset', template => '%d',
                      unit => 's', label_extra_instance => 1, instance_use => 'input_desc' },
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
        'filter-input:s'         => { name => 'filter_input' },
        'no-skip-disabled'       => { name => 'no_skip_disabled' },
        'warning-input-status:s' => { name => 'warning_input_status', default => '%{is_disabled} == 1 or %{input_state} =~ /Waiting|Ignored/i' },
        'critical-input-status:s'=> { name => 'critical_input_status', default => '%{input_state} =~ /No signal|Error|Not selectable/i and %{is_driving} == 1' },
        'warning-satellites:s'   => { name => 'warning_satellites', default => '' },
        'critical-satellites:s'  => { name => 'critical_satellites', default => '' },
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => [
        'warning_input_status', 'critical_input_status',
        'warning_satellites', 'critical_satellites'
    ]);
}

my $mapping = {
    inputCardDescription    => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.1' },
    inputCardAddress        => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.2' },
    inputIsDriving          => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.3' },
    inputState              => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.4' },
    inputIsDisabled         => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.5' },
    inputGPSSat             => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.6' },
    inputGLONASSSat         => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.7' },
    inputGALILEOSat         => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.8' },
    inputBEIDOUSat          => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.9' },
    inputDelayCompensation  => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.10' },
    inputNTPClientMode      => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.11' },
    activeRemoteNtpServer   => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.12' },
    inputIsLocalTimeEnabled => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.13' },
    inputLocalTimeOffset    => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.14' },
    inputStratum            => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.16' },
    inputPPSOffsetTB        => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.17' },
    inputPPSOffsetVClock    => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.18' },
    inputSecondOffset       => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.19' },
    inputReadyDate          => { oid => '.1.3.6.1.4.1.8955.1.8.3.1.20' },
};

my $oid_inputEntry = '.1.3.6.1.4.1.8955.1.8.3.1';

sub manage_selection {
    my ($self, %options) = @_;

    $self->{inputs} = {};
    
    my $snmp_result = $options{snmp}->get_table(
        oid => $oid_inputEntry,
        start => $mapping->{inputCardDescription}->{oid},
        end => $mapping->{inputReadyDate}->{oid},
        nothing_quit => 1
    );

    foreach my $oid (keys %{$snmp_result}) {
        next if ($oid !~ /^$mapping->{inputCardDescription}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => $instance);

        # Skip disabled inputs by default unless --no-skip-disabled
        if (!defined($self->{option_results}->{no_skip_disabled}) && 
            defined($result->{inputIsDisabled}) && $result->{inputIsDisabled} == 1) {
            $self->{output}->output_add(long_msg => "skipping disabled input #" . $instance, debug => 1);
            next;
        }

        if (defined($self->{option_results}->{filter_input}) && $self->{option_results}->{filter_input} ne '' &&
            $result->{inputCardDescription} !~ /$self->{option_results}->{filter_input}/) {
            $self->{output}->output_add(long_msg => "skipping input '" . $result->{inputCardDescription} . "'.", debug => 1);
            next;
        }

        # Clean up description and address (handle empty/invalid values)
        my $desc = defined($result->{inputCardDescription}) && $result->{inputCardDescription} ne '' 
            ? $result->{inputCardDescription} : "Input #$instance";
        my $addr = defined($result->{inputCardAddress}) && $result->{inputCardAddress} ne '' 
            ? $result->{inputCardAddress} : $instance;

        $self->{inputs}->{$instance} = {
            input_desc         => $desc,
            input_addr         => $addr,
            is_driving         => $result->{inputIsDriving},
            input_state        => $result->{inputState},
            is_disabled        => $result->{inputIsDisabled},
            gps_sat            => defined($result->{inputGPSSat}) && $result->{inputGPSSat} ne '' ? $result->{inputGPSSat} : 'N/A',
            glonass_sat        => defined($result->{inputGLONASSSat}) && $result->{inputGLONASSSat} ne '' ? $result->{inputGLONASSSat} : 'N/A',
            galileo_sat        => defined($result->{inputGALILEOSat}) && $result->{inputGALILEOSat} ne '' ? $result->{inputGALILEOSat} : 'N/A',
            beidou_sat         => defined($result->{inputBEIDOUSat}) && $result->{inputBEIDOUSat} ne '' ? $result->{inputBEIDOUSat} : 'N/A',
            pps_offset_tb      => defined($result->{inputPPSOffsetTB}) ? $result->{inputPPSOffsetTB} : 0,
            pps_offset_vclock  => defined($result->{inputPPSOffsetVClock}) ? $result->{inputPPSOffsetVClock} : 0,
            second_offset      => defined($result->{inputSecondOffset}) ? $result->{inputSecondOffset} : 0,
        };
    }
    
    if (scalar(keys %{$self->{inputs}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No time inputs found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check time inputs status (GPS, GNSS, NTP, PTP, IRIG, DCF, etc.).

=over 8

=item B<--filter-input>

Filter inputs by description (can be a regexp).

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^input-status$'

=item B<--warning-input-status>

Define the conditions to match for the status to be WARNING (default: '%{is_disabled} == 1 or %{input_state} =~ /Waiting|Ignored/i').
You can use the following variables: %{input_state}, %{input_desc}, %{is_driving}, %{is_disabled}

=item B<--critical-input-status>

Define the conditions to match for the status to be CRITICAL (default: '%{input_state} =~ /No signal|Error|Not selectable/i and %{is_driving} == 1').
You can use the following variables: %{input_state}, %{input_desc}, %{is_driving}, %{is_disabled}

=item B<--warning-satellites>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{gps_sat}, %{glonass_sat}, %{galileo_sat}, %{beidou_sat}

=item B<--critical-satellites>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{gps_sat}, %{glonass_sat}, %{galileo_sat}, %{beidou_sat}

=item B<--warning-*>

Warning threshold.
Can be: 'pps-offset-tb', 'pps-offset-vclock', 'second-offset'.

=item B<--critical-*>

Critical threshold.
Can be: 'pps-offset-tb', 'pps-offset-vclock', 'second-offset'.

=back

=cut
