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

package hardware::devices::gorgy::ntpserver::snmp::mode::systeminfo;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {});
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

my $mapping = {
    productName      => { oid => '.1.3.6.1.4.1.8955.1.8.1.1' },
    versionNumber    => { oid => '.1.3.6.1.4.1.8955.1.8.1.2' },
    serialNumber     => { oid => '.1.3.6.1.4.1.8955.1.8.1.3' },
    timeBaseVersion  => { oid => '.1.3.6.1.4.1.8955.1.8.1.4' },
    macAddress       => { oid => '.1.3.6.1.4.1.8955.1.8.1.5' },
    messageString    => { oid => '.1.3.6.1.4.1.8955.1.8.1.6' },
    resetInfo        => { oid => '.1.3.6.1.4.1.8955.1.8.1.7' },
    currentDate      => { oid => '.1.3.6.1.4.1.8955.1.8.1.9' },
};

sub run {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_leef(
        oids => [
            $mapping->{productName}->{oid} . '.0',
            $mapping->{versionNumber}->{oid} . '.0',
            $mapping->{serialNumber}->{oid} . '.0',
            $mapping->{timeBaseVersion}->{oid} . '.0',
            $mapping->{macAddress}->{oid} . '.0',
            $mapping->{messageString}->{oid} . '.0',
            $mapping->{resetInfo}->{oid} . '.0',
            $mapping->{currentDate}->{oid} . '.0'
        ],
        nothing_quit => 1
    );
    my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => '0');

    $self->{output}->output_add(
        severity => 'OK',
        short_msg => sprintf(
            "Product: %s, Serial: %s, Firmware: %s",
            $result->{productName},
            $result->{serialNumber},
            $result->{versionNumber}
        )
    );

    $self->{output}->output_add(long_msg => sprintf("Product Name: %s", $result->{productName}));
    $self->{output}->output_add(long_msg => sprintf("Serial Number: %s", $result->{serialNumber}));
    $self->{output}->output_add(long_msg => sprintf("Firmware Version: %s", $result->{versionNumber}));
    $self->{output}->output_add(long_msg => sprintf("TimeBase Version: %s", $result->{timeBaseVersion}));
    $self->{output}->output_add(long_msg => sprintf("MAC Address: %s", $result->{macAddress}));
    $self->{output}->output_add(long_msg => sprintf("Current Date: %s", $result->{currentDate}));
    $self->{output}->output_add(long_msg => sprintf("Last Reset Reason: %s", $result->{resetInfo}));
    $self->{output}->output_add(long_msg => sprintf("System Message: %s", $result->{messageString}));

    $self->{output}->display();
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Display system information (product name, serial number, firmware version, MAC address, etc.).

=over 8

=back

=cut
