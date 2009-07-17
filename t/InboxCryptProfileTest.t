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

use Time::HiRes qw/gettimeofday tv_interval/;

use Test::More tests => 9; # increment this value for each test you create

my $session = WebGUI::Test->session;
$session->db->write("delete from inbox where userId = 1");
# set up crypt tests
my $ct = WebGUI::CryptTest->new($session,'testText');
my $crypt = WebGUI::Crypt->new($session);

#create destination Simple provider
my $cryptSetting = $session->config->get('crypt');
$cryptSetting->{'SimpleTest'} = {
         "provider" => "WebGUI::Crypt::Simple",
         "name" => "Test Simple Provider - delete me",
         "key" => "Bingowashisnamo!"
      };
$cryptSetting->{'SimpleTest2'} = {
         "provider" => "WebGUI::Crypt::Simple",
         "name" => "Test Simple Provider2 - delete me",
         "key" => "had a farmer!"
      };
$session->config->set('crypt', $cryptSetting);



# Store current survey crypt setting
my $temp = $crypt->lookupProviderId({table=>'Survey_response', field=>'reponseJSON'});
my $defaultProviderId = defined $temp ? $temp : 'None';

# Set provider to Simple
$crypt->setProvider({table=>'inbox', field=>'message', key=>'messageId','providerId'=>'SimpleTest'});
#$crypt->setProvider({table=>'inbox', field=>'message', key=>'messageId','providerId'=>'None'});

# get a user so we can test retrieving messages for a specific user
my $user = WebGUI::User->new($session, 3);

# Begin tests by getting an inbox object
my $inbox = WebGUI::Inbox->new($session); 
my @messages;
my $t0 = [gettimeofday];
for(1 .. 10000){
    push(@messages,addMessage());
}
$session->log->error(tv_interval ( $t0 )." time to load messages\n\n\n");
$t0 = [gettimeofday];
# Set provider to Simple
#$crypt->setProvider({table=>'inbox', field=>'message', key=>'messageId','providerId'=>'SimpleTest2'});
$session->log->error(tv_interval ( $t0 )." time to convert messages\n\n\n");

########################
# create a new message #
########################
sub addMessage{
    my $message_body = <<EOF;
Reporting from Tehran and Beirut -- Security forces fired tear gas and plainclothes militiamen armed with batons charged at crowds of protesters gathered near Tehran University after a Friday prayer sermon delivered by the cleric and opposition supporter Ayatollah Ali Akbar Hashemi Rafsanjani, his first appearance at the nation's weekly keynote sermon since before the election.

Rafsanjani, in a closely watched speech, lashed out at the hard-line camp supporting President Mahmoud Ahmadinejad, criticized the June 12 election results and promoted several key opposition demands. However, he failed to offer a solution to what has emerged as Iran's worst political crisis in decades.
EOF
    my $new_message = {
        message => $message_body,
        groupId => 3,
        userId => 1,
    };

    my $message = $inbox->addMessage($new_message);

    my $messageId = $message->getId;
    return $messageId;
}
####################################
# get a message based on messageId #
####################################

#########################################################
# get a list (arrayref) of messages for a specific user #
#########################################################
#my $messageList = $inbox->getMessagesForUser($user);
#my $message_cnt = scalar(@{$messageList});

END {
    #for my $messageId(@messages){
    #    my $message = $inbox->getMessage($messageId);
    #    $session->db->write('delete from inbox where messageId = ?', [$message->getId]);
    #}
    #$crypt->setProvider({table=>'inbox', field=>'message', key=>'messageId','providerId'=>$defaultProviderId});
    delete $cryptSetting->{'SimpleTest'};
    delete $cryptSetting->{'SimpleTest2'};
    $session->config->set('crypt', $cryptSetting);
}
