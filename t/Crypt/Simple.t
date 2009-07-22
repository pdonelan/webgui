# Tests WebGUI::Crypt::Provider::Simple
#
#

use strict;
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
plan tests => 91;

#----------------------------------------------------------------------------
# put your tests here
use_ok('WebGUI::Crypt::Provider::Simple');

for my $providerId (qw(SimpleTest SimpleTest2 SimpleTest3)) {
    #######################################################################
    #
    # constructor
    #
    #######################################################################
    my $crypt = WebGUI::Crypt::Provider::Simple->new( $session, $ct->getProviderConfig($providerId) );
    isa_ok( $crypt, 'WebGUI::Crypt::Provider::Simple', 'constructor works' );
    is( $crypt->providerId(), $providerId, "provider was created ");

    #######################################################################
    #
    # en/decrypt[_hex]
    #
    #######################################################################
    # These call the WebGUI::Crypt::Provider::Simple object
    my @expected = (
        [ 'hi', 'hi'],
        [ '', ''],
        [ undef, ''], # note, undef becomes empty string when ciphertext is decrypted
    );
    for my $expect (@expected) {
        my ($start, $end) = @$expect;
        # Check round trip..
        my $ciphertext = $crypt->encrypt($start);
        isnt($ciphertext, $start, "input [$start] altered");
        is($crypt->decrypt($ciphertext), $end, "output [$end] expected at end of roundtrip");
    }
    
    # These call the WebGUI::Crypt::Provider::Simple object
    is($crypt->decrypt($crypt->encrypt('hi')), 'hi', 'Provider roundtrip on string: "hi"');
    is($crypt->decrypt($crypt->encrypt('')), '', 'Provider roundtrip on empty string');
        
    for my $method (qw(crypt crypt_hex)) {
        my $encrypt = "en$method";
        my $decrypt = "de$method";
        
        # These go via the session->crypt object, and involve headers
        for my $expect (@expected) {
            my ($start, $end) = @$expect;
            # Check round trip..
            my $encrypted = $session->crypt->encrypt($start, { providerId => $providerId });
            my ($pId, $ciphertext) = $session->crypt->parseHeader($encrypted);
            is($pId, $providerId, "Provider: $providerId");
            isnt($ciphertext, $start, "input [$start] altered");
            is($session->crypt->decrypt($encrypted), $end, "output [$end] expected at end of roundtrip");
        }
        
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