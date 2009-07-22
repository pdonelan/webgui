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
use lib "$FindBin::Bin/lib";
use WebGUI::Test;
use WebGUI::Session;

use WebGUI::Inbox;
use WebGUI::User;
use WebGUI::CryptTest;

use Test::More tests => 14; # increment this value for each test you create

my $session = WebGUI::Test->session;

# get a user so we can test retrieving messages for a specific user
my $user = WebGUI::User->new($session, 3);

# Begin tests by getting an inbox object
my $inbox = WebGUI::Inbox->new($session); 
isa_ok($inbox, 'WebGUI::Inbox');
ok(defined ($inbox), 'new("new") -- object reference is defined');

########################
# create a new message #
########################
my $message_body = 'Test message';
my $new_message = {
    message => $message_body,
    groupId => 3,
    userId => 1,
};

my $message = $inbox->addMessage($new_message);
isa_ok($message, 'WebGUI::Inbox::Message');

ok(defined($message), 'addMessage returned a response');
ok($message->{_properties}{message} eq $message_body, 'Message body set');

my $messageId = $message->getId;
ok($messageId, 'messageId retrieved');

####################################
# get a message based on messageId #
####################################
$message = $inbox->getMessage($messageId);
ok($message->getId == $messageId, 'getMessage returns message object');
ok($message->{_properties}{message} eq $message_body, 'Message body still matches encrypted message in DB');

#########################################################
# get a list (arrayref) of messages for a specific user #
#########################################################
my $messageList = $inbox->getMessagesForUser($user);
my $message_cnt = scalar(@{$messageList});
ok($message_cnt > 0, 'Messages returned for user');

#########################################################
# crypt #
#########################################################
{
    # Remove existing test message
    $session->db->write('delete from inbox where messageId = ?', [$message->getId]);
    
    # Create crypt test object
    my $ct = WebGUI::CryptTest->new( $session, 'Inbox.t' );

    # Start off with inbox encryption off
    $session->crypt->setProvider(
        { table => 'inbox', field => 'message', key => 'messageId', providerId => 'None' } );
    my $msg1 = $inbox->addMessage( { message => 'my msg1', groupId => 3, userId => 1 } );
    is( $session->db->quickScalar( 'select message from inbox where messageId = ?', [ $msg1->getId ] ),
        'my msg1', 'Start with encryption off' );

    # Set provider to SimpleTest, new messages should use this
    $session->crypt->setProvider(
        { table => 'inbox', field => 'message', key => 'messageId', providerId => 'SimpleTest' } );
    my $msg2 = $inbox->addMessage( { message => 'my msg2', groupId => 3, userId => 1 } );
    like( $session->db->quickScalar( 'select message from inbox where messageId = ?', [ $msg2->getId ] ),
        qr/^CRYPT:SimpleTest:/, '..and now encryption is on' );
    is( $msg2->get('message'), 'my msg2', '..but API returns unencrypted message' );
    is( $session->db->quickScalar( 'select message from inbox where messageId = ?', [ $msg1->getId ] ),
        'my msg1', '..and msg1 still unencrypted' );

    # Set provider to SimpleTest2 and run the workflow
    $session->crypt->setProvider(
        { table => 'inbox', field => 'message', key => 'messageId', providerId => 'SimpleTest2' } );
    WebGUI::Crypt->startCryptWorkflow($session);
    is( $session->db->quickScalar(
            'select count(*) from inbox where messageId in (?,?) and message like "CRYPT:SimpleTest2:%"',
            [ $msg1->getId, $msg2->getId ]
        ),
        2,
        '..until we re-encrypt them both via the workflow'
    );
    
    # Clean up
    $msg1->delete;
    $msg2->delete;
    $session->crypt->setProvider(
        { table => 'inbox', field => 'message', key => 'messageId', 'providerId' => 'None' } );
}

END {
    $session->db->write('delete from inbox where messageId = ?', [$message->getId]);
}
