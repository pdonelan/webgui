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
plan tests => 37;

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
    # en/decrypt[_hex]
    #
    #######################################################################
    for my $method (qw(crypt crypt_hex)) {
        my $encrypt = "en$method";
        my $decrypt = "de$method";
        {
            my $t = $crypt->$encrypt('hi');
            my ( $providerId, $text ) = $session->crypt->parseHeader($t);
            is( $crypt->$decrypt($text), 'hi', "$encrypt hi should return hi");
        }
        {
            my $t = $crypt->$encrypt('');
            my ( $providerId, $text ) = $session->crypt->parseHeader($t);
            is( $crypt->$decrypt($text), '', "encrypt nothing should return nothing");
        }
        is($session->crypt->$decrypt($session->crypt->$encrypt('hi', { providerId => $providerId })), 'hi', 'Roundtrip on string: "hi"');
        is($session->crypt->$decrypt($session->crypt->$encrypt('', { providerId => $providerId })), '', '..same for empty string');
        
        if ($ct->getProviderConfig($providerId)->{salt}) {
            is( 
                $session->crypt->$encrypt('hi', { providerId => $providerId }), 
                $session->crypt->$encrypt('hi', { providerId => $providerId }),
                'fixed salt, so same encrypted string every time (hello rainbow table attack)'
            );
        } else {
            isnt( 
                $session->crypt->$encrypt('hi', { providerId => $providerId }), 
                $session->crypt->$encrypt('hi', { providerId => $providerId }),
                'random salt, so encrypted string is different every time'
            );
        }
    }
}