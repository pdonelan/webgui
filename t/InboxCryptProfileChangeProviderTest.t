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



# Set provider to Simple
#$crypt->setProvider({table=>'inbox', field=>'message', key=>'messageId','providerId'=>'SimpleTest2'});
$crypt->setProvider({table=>'inbox', field=>'message', key=>'messageId','providerId'=>'None'});



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
