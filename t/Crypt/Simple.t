# Tests WebGUI::Crypt::Simple
#
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::More;
use Test::Deep;
use Exception::Class;

use WebGUI::Test;    # Must use this before any other WebGUI modules
use WebGUI::CryptTest;

#----------------------------------------------------------------------------
# Init
my $session = WebGUI::Test->session;

#----------------------------------------------------------------------------
# Create test data
my $ct = WebGUI::CryptTest->new( $session, 'Simple.t' );

#----------------------------------------------------------------------------
# Tests
WebGUI::Error->Trace(1);    # Turn on tracing of uncaught Exception::Class exceptions
plan tests => 22;

#----------------------------------------------------------------------------
# put your tests here
use_ok('WebGUI::Crypt::Simple');

for my $providerId (qw(SimpleTest SimpleTest2 SimpleTest3)) {
    #######################################################################
    #
    # constructor
    #
    #######################################################################
    my $crypt = WebGUI::Crypt::Simple->new( $session, $ct->getProviderConfig($providerId) );
    isa_ok( $crypt, 'WebGUI::Crypt::Simple', 'constructor works' );
    is( $crypt->providerId(), $providerId, "provider was created ");

    #######################################################################
    #
    # en/decrypt
    #
    #######################################################################
    {
        my $t = $crypt->encrypt_hex('hi');
        $t =~ /CRYPT:(.*?):(.*)/;
        is( $crypt->decrypt_hex($2), 'hi', 'encrypt hi should return hi');
    }
    {
        my $t = $crypt->encrypt_hex('');
        $t =~ /CRYPT:(.*?):(.*)/;
        my $cipher = $2;
        is( $crypt->decrypt_hex($cipher), '', 'encrypt nothing should return nothing');
    }
    is($session->crypt->decrypt_hex($session->crypt->encrypt_hex('hi', { providerId => $providerId })), 'hi', 'Roundtrip on string: "hi"');
    is($session->crypt->decrypt_hex($session->crypt->encrypt_hex('', { providerId => $providerId })), '', '..same for empty string');
    
    if ($ct->getProviderConfig($providerId)->{salt}) {
        is( 
            $session->crypt->encrypt_hex('hi', { providerId => $providerId }), 
            $session->crypt->encrypt_hex('hi', { providerId => $providerId }),
            'fixed salt, so same encrypted string every time (hello rainbow table attack)'
        );
    } else {
        isnt( 
            $session->crypt->encrypt_hex('hi', { providerId => $providerId }), 
            $session->crypt->encrypt_hex('hi', { providerId => $providerId }),
            'random salt, so encrypted string is different every time'
        );
    }
}