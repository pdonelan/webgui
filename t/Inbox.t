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

use Test::More tests => 19; # increment this value for each test you create

my $session = WebGUI::Test->session;

# get a user so we can test retrieving messages for a specific user
my $admin = WebGUI::User->new($session, 3);

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
    userId  => 1,
};

my $message = $inbox->addMessage($new_message,{ testing => 1, });
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
my $messageList = $inbox->getMessagesForUser($admin);
my $message_cnt = scalar(@{$messageList});
is($message_cnt,  1, 'User only has 1 messages');
$message->setDeleted(3);
is(scalar(@{ $inbox->getMessagesForUser($admin) }),  0, 'User has no undeleted messages');
$message->delete(3);

#########################################################
#
# Check user filtering
#
#########################################################

my @senders = ();

push @senders, WebGUI::User->create($session);
push @senders, WebGUI::User->create($session);
push @senders, WebGUI::User->create($session);
WebGUI::Test->usersToDelete(@senders);
$senders[0]->username('first');
$senders[0]->profileField('firstName', 'First Only');
$senders[1]->username('last');
$senders[1]->profileField('lastName', 'Last Only');
$senders[2]->username('wholename');
$senders[2]->profileField('firstName', 'Tom');
$senders[2]->profileField('lastName', 'Jones');

$inbox->addMessage({
    message => "First message",
    userId  => 3,
    sentBy  => $senders[0]->userId,
},{
    testing => 1,
});

$inbox->addMessage({
    message => "Second message",
    userId  => 3,
    sentBy  => $senders[1]->userId,
},{
    testing => 1,
});

$inbox->addMessage({
    message => "Third message",
    userId  => 3,
    sentBy  => $senders[2]->userId,
},{
    testing => 1,
});

$inbox->addMessage({
    message => "Fourth message",
    userId  => 3,
    sentBy  => $senders[2]->userId,
},{
    testing => 1,
});

is(scalar @{ $inbox->getMessagesForUser($admin) }, 4, 'Added 3 messages by various users');
is(scalar @{ $inbox->getMessagesForUser($admin, '', '', '', 'sentBy='.$session->db->quote($senders[0]->userId)) }, 1, '1 message by sender[0]');
is(scalar @{ $inbox->getMessagesForUser($admin, '', '', '', 'sentBy='.$session->db->quote($senders[1]->userId)) }, 1, '1 message by sender[1]');
is(scalar @{ $inbox->getMessagesForUser($admin, '', '', '', 'sentBy='.$session->db->quote($senders[2]->userId)) }, 2, '2 messages by sender[2]');

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
    my $msg1 = $inbox->addMessage( { message => 'my msg1', userId => 3 } );
    is( $session->db->quickScalar( 'select message from inbox where messageId = ?', [ $msg1->getId ] ),
        'my msg1', 'Start with encryption off' );

    # Set provider to SimpleTest, new messages should use this
    $session->crypt->setProvider(
        { table => 'inbox', field => 'message', key => 'messageId', providerId => 'SimpleTest' } );
    my $msg2 = $inbox->addMessage( { message => 'my msg2', userId => 3 } );
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
    foreach my $message (@{ $inbox->getMessagesForUser($admin, 1000) } ) {
        next unless $message;
        $message->setDeleted(3);
        $message->delete(3);
    }
}
