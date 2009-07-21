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
use Benchmark qw(:all);

use lib "$FindBin::Bin/t/lib";
use WebGUI::Test;    # Must use this before any other WebGUI modules
use WebGUI::CryptTest;
use WebGUI::Inbox;
use WebGUI::User;

#----------------------------------------------------------------------------
# Init
my $session = WebGUI::Test->session;
my $tests_to_run = 10_000;

#----------------------------------------------------------------------------
# Create test data

# Create test user
my $user = WebGUI::User->new($session, 'new');
my $userId = $user->userId;
WebGUI::Test->usersToDelete($user);

# Begin tests by getting an inbox object
my $inbox = WebGUI::Inbox->new($session);

# Firstly, delete ALL inbox messages (otherwise the "change provider" test below will do extra work)
$session->db->write("delete from inbox");

# First add without provider set
{
    $session->db->write("delete from inbox where userId = ?", [$userId]);
    my $ct = WebGUI::CryptTest->new( $session, 'crypt_benchmark.pl' );
    timethis ($tests_to_run, "addMessage()");
    my $msgs = $session->db->quickScalar('select count(*) from inbox where userId = ?', [$userId]);
    if ($msgs != $tests_to_run) {
        die "Got $msgs messages, expected $tests_to_run";
    }
}

# Then re-run with Provider set to None
{
    $session->db->write("delete from inbox where userId = ?", [$userId]);
    my $ct = WebGUI::CryptTest->new( $session, 'crypt_benchmark.pl' );
    $session->crypt->setProvider({table=>'inbox', field=>'message', key=>'messageId','providerId'=>'None'});
    timethis ($tests_to_run, "addMessage()");
    my $msgs = $session->db->quickScalar('select count(*) from inbox where userId = ?', [$userId]);
    if ($msgs != $tests_to_run) {
        die "Got $msgs messages, expected $tests_to_run";
    }
}

# Now change provider to SimpleTest
{
    my $ct = WebGUI::CryptTest->new( $session, 'crypt_benchmark.pl' );
    timethis (1, "changeAndWaitForWorkflow()");
    my $encrypted = $session->db->quickScalar('select count(*) from inbox where message like "CRYPT:SimpleTest:%" and userId = ?', [$userId]);
    my $unencrypted = $session->db->quickScalar('select count(*) from inbox where message not like "CRYPT:SimpleTest:%" and userId = ?', [$userId]);
    if ($encrypted != $tests_to_run || $unencrypted != 0) {
        die "Got $encrypted encrypted, $unencrypted unencrypted messages, expected $tests_to_run and 0";
    }
}

# Now re-add with provider set to SimpleTest
{
    $session->db->write("delete from inbox where userId = ?", [$userId]);
    my $ct = WebGUI::CryptTest->new( $session, 'crypt_benchmark.pl' );
    $session->crypt->setProvider({table=>'inbox', field=>'message', key=>'messageId','providerId'=>'SimpleTest'});
    timethis ($tests_to_run, "addMessage()");
    my $msgs = $session->db->quickScalar('select count(*) from inbox where userId = ?', [$userId]);
    if ($msgs != $tests_to_run) {
        die "Got $msgs messages, expected $tests_to_run";
    }
}

sub addMessage {
    my $message_body = 

    $inbox->addMessage({
        userId => $userId,
        message => <<EOF,
WebGUI is your Content Management System Solution. Join the thousands of businesses, agencies, universities and school districts who have discovered just how easy the web can be. See for yourself why WebGUI is web done right.

We have an active community of developers. You'll find great sources to learn all about WG, and places to share your thoughts and views through the blogs or on the wikis. Contribute to our success with RFE or bug submissions.

Come join our community to contribute, discuss and/or troubleshoot about design issues with WebGUI. Visit forums, a design wiki,  and more!
EOF
    });
}

sub changeAndWaitForWorkflow {
    $session->crypt->setProvider({table=>'inbox', field=>'message', key=>'messageId','providerId'=>'SimpleTest'});
    print "Starting workflow (if you get a pause here, workflow is probably running in realtime)\n";
    WebGUI::Crypt->startCryptWorkflow($session);
    print "Workflow started (if you get a pause here, workflow is probably running via SPECTRE)\n";
    my $workflow = WebGUI::Workflow->new($session, 'CryptProviders00000001');
    while ( my @instances = @{ $workflow->getInstances() } ) {
        print "Still waiting..\n";
        sleep 1;
    }
}