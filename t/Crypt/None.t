# Tests WebGUI::Crypt::None
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
plan tests => 7;

#----------------------------------------------------------------------------
# put your tests here
use_ok('WebGUI::Crypt::None');

#######################################################################
#
# constructor
#
#######################################################################
my $crypt = WebGUI::Crypt::None->new( $session, $ct->getProviderConfig('None') );
isa_ok( $crypt, 'WebGUI::Crypt::None', 'constructor works' );
is( $crypt->providerId(), 'None', "provider was created ");

#######################################################################
#
# en/decrypt
#
#######################################################################
is( $crypt->decrypt($crypt->encrypt("hi")), 'hi', 'encrypt hi should return hi');
is($session->crypt->decrypt($session->crypt->encrypt('hi', { providerId => 'None' })), 'hi', '..same via session->crypt');
is( $crypt->decrypt($crypt->encrypt()), undef, 'roundtrip encryption on undef should return empty string');
is($session->crypt->decrypt($session->crypt->encrypt('', { providerId => 'None' })), '', '..same via session->crypt');