#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2009 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use FindBin;
use strict;
use lib "$FindBin::Bin/../../lib";
use Test::More;

use WebGUI::Test;    # Must use this before any other WebGUI modules
use WebGUI::CryptTest;

#----------------------------------------------------------------------------
# Init
my $session = WebGUI::Test->session;

#----------------------------------------------------------------------------
# Create test data
my $ct = WebGUI::CryptTest->new( $session, 'CryptUpdateFieldProviders.t' );

#----------------------------------------------------------------------------
# Tests
WebGUI::Error->Trace(1);    # Turn on tracing of uncaught Exception::Class exceptions
plan tests => 4;

#----------------------------------------------------------------------------
# put your tests here
use_ok('WebGUI::Workflow::Activity::CryptUpdateFieldProviders');

# encryptTest table contains our known plaintext string, thanks to WebGUI::CryptTest
is($session->db->quickScalar("select testField from encryptTest where id = 1"),'CryptUpdateFieldProviders.t','Start with known plaintext');

############
# Set the provider to simple for the test table, and trigger the workflow
############
$session->crypt->setProvider({table=>'encryptTest', field=>'testField', key=>'id','providerId'=>'SimpleTest'});
WebGUI::Crypt->startCryptWorkflow($session);

# Make sure the test string is no longer plain text
like($session->db->quickScalar("select testField from encryptTest where id = 1"),qr/^CRYPT:SimpleTest:/, 'Text should now be encrypted');

############
# Change provider to None and re-trigger the workflow
############

$session->crypt->setProvider({table=>'encryptTest', field=>'testField', key=>'id','providerId'=>'None'});
WebGUI::Crypt->startCryptWorkflow($session);

# Make sure the test string is now back to plain text
is($session->db->quickScalar("select testField from encryptTest where id = 1"),'CryptUpdateFieldProviders.t','Start with known plaintext');