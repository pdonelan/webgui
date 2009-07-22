# Tests that we can decrypt WebGUI::Crypt ciphertexts using OpenSSL
# N.B. Assumes that the openssl binary lives at: /data/wre/prereqs/bin/openssl
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
use MIME::Base64;

#----------------------------------------------------------------------------
# Init
my $session = WebGUI::Test->session;

#----------------------------------------------------------------------------
# Create test data
my $ct = WebGUI::CryptTest->new( $session, 'OpenSSL.t' );

#----------------------------------------------------------------------------
# Tests
WebGUI::Error->Trace(1);    # Turn on tracing of uncaught Exception::Class exceptions
plan tests => 2;

#----------------------------------------------------------------------------
# put your tests here

#----------------------------------------------------------------------------

for my $providerId qw(SimpleTest SimpleTest2 SimpleTest3) {
    
    # skip SimpleTest2 bc it uses Blowfish
    next if $providerId eq 'SimpleTest2';
    
    my $key       = $ct->getProviderConfig($providerId)->{key};
    my $plaintext = 'test';

    # First ask provider to encrypt
    my $encrypted = $session->crypt->encrypt( $plaintext, { providerId => $providerId } );

    # Then parse header
    my ( $pId, $ciphertext ) = $session->crypt->parseHeader($encrypted);

    # Then base64 encode the way openssl likes it
    my $ciphertext_base64 = encode_base64($ciphertext);    # Note to the curious, base64 adds a newline to the end, which is expected and required for OpenSSL compat

    # Construct our command:
    my $cmd = qq{echo "$ciphertext_base64" | /data/wre/prereqs/bin/openssl enc -aes256 -salt -a -d -k "$key"};

    diag("Running command: $cmd");
    my $output = `$cmd`;
    is( $output, $plaintext, 'Decrypted ciphertext using OpenSSL' ) or warn $output;
}