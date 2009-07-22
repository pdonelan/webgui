package WebGUI::CryptTest;

use strict;
use warnings;
use Class::InsideOut qw{ :std };

readonly session       => my %session;
private cryptEnabled   => my %cryptEnabled;
readonly testTable     => my %testTable;
readonly testField     => my %testField;
readonly testKey     => my %testKey;
private originalConfig => my %originalConfig;

sub new {
    my ( $class, $session, $testText ) = @_;

    # Register Class::InsideOut object..
    my $self = register $class;

    # Initialise object properties..
    my $id = id $self;
    $session{$id}              = $session;
    $testTable{ id $self}      = 'encryptTest';
    $testField{ id $self}      = 'testField';
    $testKey{ id $self}      = 'id';
    $originalConfig{ id $self} = $self->session->config->get('crypt');
    $self->_setCryptDefault();
    $self->_createTestTable($testText);
    $self->_createTestConfig();
    return $self;
}

sub _createTestTable {
    my ( $self, $testText ) = @_;
    my $testTable = $testTable{id $self};
    my $testField = $testField{id $self};
    my $testKey = $testKey{id $self};
    $self->session->db->write("drop table if exists `$testTable`");
    $self->session->db->write(
        "CREATE TABLE `$testTable` ( `$testKey` char(22)  NOT NULL, `$testField` LONGTEXT  NOT NULL)"
    );
    $self->session->db->write(
        "insert into `$testTable` (`$testKey`, `$testField`) values ('1',?) on duplicate key update $testField = ?",[ $testText, $testText ] 
    );
}

sub _createTestConfig {
    my $self = shift;
    $self->session->config->set(
        'crypt',
        {   None => {
                name     => 'None',
                provider => 'WebGUI::Crypt::Provider::None',
            },
            SimpleTest => {
                provider => "WebGUI::Crypt::Provider::Simple",
                name     => "Test Simple Provider - delete me",
                key      => "Bingowashisnamo!",
                cipher   => 'Crypt::Rijndael',
            },
            SimpleTest2 => {
                provider => "WebGUI::Crypt::Provider::Simple",
                name     => "Test Simple Provider2 - Blowfish",
                key      => "had a farmer!",
                cipher   => 'Crypt::Blowfish',
            },
            SimpleTest3 => {
                provider => "WebGUI::Crypt::Provider::Simple",
                name     => "Test Simple Provider3 - unsalted",
                key      => "ee ii eee ii ooh!",
                cipher   => 'Crypt::Rijndael',
                salt     => 'unsalted',
            },
        }
    );
    $self->session->db->write("delete from cryptFieldProviders");
}

=head2 getProviderConfig ($providerId)

Returns a hashref containing provider config from the settings file, with the 
extra providerId field added. This is typically used to manually instantiate
a Crypt provider for testing, using one of the test providers created by
this class e.g.
 my $ct = WebGUI::CryptTest->new( $session, 'None.t' );
 my $none = WebGUI::Crypt::Provider::None->new( $session, $ct->getProviderConfig('None') );

=head3 providerId

A providerId, must match one of the providerIds in the config file (see L<_createTestConfig>

=cut

sub getProviderConfig {
    my ( $self, $providerId ) = @_;
    my $providerConfig = $self->session->config->get('crypt')->{$providerId} or do {
        warn "Invalid providerId: $providerId";
        return {};
    };
    my %providerConfig = %$providerConfig; # make a safe copy
    $providerConfig{providerId} = $providerId;
    return \%providerConfig;
}

sub _setCryptDefault {
    my ($self) = @_;
    $cryptEnabled{ id $self} = $self->session->setting->get('cryptEnabled');
    $self->session->setting->set( 'cryptEnabled', 1 );
    $self->session->setting->set( 'cryptTriggerUpdateOnProviderChange', 0 );
}

sub DEMOLISH {
    my ($self) = @_;
    $self->session->setting->set( 'cryptEnabled', $cryptEnabled{ id $self} );
    my $testTable = $testTable{id $self};
    my $testField = $testField{id $self};
    my $testKey = $testKey{id $self};
    $self->session->db->write("drop table if exists `$testTable`");
    $self->session->db->write("delete from cryptFieldProviders");

    # Restore original crypt config
    my $config = $originalConfig{id $self};
    # Remove the providerId field we may have added via L<getProviderConfig>
    for my $providerSettings (values %$config) {
        delete $providerSettings->{providerId};
    }
    $self->session->config->set( 'crypt', $config );
}
1;
