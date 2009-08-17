# Tests WebGUI::Crypt::Provider::Simple
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
use WebGUI::Form_Checking;


#----------------------------------------------------------------------------
# Init
my $session = WebGUI::Test->session;

#----------------------------------------------------------------------------
# Create test data
my $ct = WebGUI::CryptTest->new( $session, 'CryptProvider.t' );

#----------------------------------------------------------------------------
# Tests
WebGUI::Error->Trace(1);    # Turn on tracing of uncaught Exception::Class exceptions
plan tests => 3;

#----------------------------------------------------------------------------
# put your tests here
use_ok('WebGUI::Form::CryptProvider');
my $cp = WebGUI::Form::CryptProvider->new($session, {
    name => 'MyCryptProvider',
    label     => 'My Crypt Provider',
});
is($cp->getDefaultValue, 'None', 'provider defaults to None');

# getOptions should return all providers that were created by WebGUI::CryptTest
$cp->toHtml; # Causes options to be set (a bit hacky)
cmp_deeply($cp->getOptions, {
        None => 'None',
        SimpleTest => "Test Simple Provider",
        SimpleTest2 => "Test Simple Provider 2",
        SimpleTest3 => "Test Simple Provider 3 - unsalted",
    }, 'getOptions gives us all providers created by WebGUI::CryptTest');