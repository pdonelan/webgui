# Tests WebGUI::Crypt::Provider::None
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
my $ct = WebGUI::CryptTest->new( $session, 'None.t' );

#----------------------------------------------------------------------------
# Tests
WebGUI::Error->Trace(1);    # Turn on tracing of uncaught Exception::Class exceptions
plan tests => 21;

#----------------------------------------------------------------------------
# put your tests here
use_ok('WebGUI::Crypt::Provider::None');

#######################################################################
#
# constructor
#
#######################################################################
my $crypt = WebGUI::Crypt::Provider::None->new( $session, $ct->getProviderConfig('None') );
isa_ok( $crypt, 'WebGUI::Crypt::Provider::None', 'constructor works' );
is( $crypt->providerId(), 'None', "provider was created ");

#######################################################################
#
# en/decrypt
#
#######################################################################
# These call the WebGUI::Crypt::Provider::None object, and all do nothing
for my $input ('hi', '', undef) {
    is($crypt->encrypt($input), $input, 'encrypt returns [$input] unchanged');
    is($crypt->decrypt($input), $input, 'decrypt returns [$input] unchanged');
}

for my $method (qw(crypt crypt_hex)) {
    my $encrypt = "en$method";
    my $decrypt = "de$method";
    
    # These go via the session->crypt object, and all do nothing
    for my $input ('hi', '', undef) {
        is($session->crypt->encrypt($input, { providerId => 'None' }), $input, 'session->crypt->encrypt returns [$input] unchanged');
        is($session->crypt->decrypt($input), $input, 'session->crypt->decrypt returns [$input] unchanged');
    }
}