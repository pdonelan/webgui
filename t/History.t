#

use FindBin;
use strict;
use lib "$FindBin::Bin/lib";

use WebGUI::Test;

use Test::More;
use Test::Deep;

#----------------------------------------------------------------------------
# Init
my $session = WebGUI::Test->session;

#----------------------------------------------------------------------------
# Tests
plan tests => 22;

#----------------------------------------------------------------------------
# put your tests here
use_ok('WebGUI::History');

my ($h, $h2, $h3);
my $user = WebGUI::User->new($session, 'new');
WebGUI::Test->usersToDelete($user);

###
# WebGUI::History->create
$h = WebGUI::History->create(
    $session,
    {   historyEventId => 'TEST',
        userId         => $user->userId,
        data           => { test => 'abc' }
    }
);
isa_ok( $h, 'WebGUI::History', 'Created new History object' );

$h2 = WebGUI::History->create(
    $session,
    {   historyEventId => 'TEST2',
        userId         => $user->userId,
        data           => { test => 'def' }
    }
);
isa_ok( $h2, 'WebGUI::History', 'Created second History object' );

###
# WebGUI::History->get

is( $h->get('historyEventId'), 'TEST', 'get() gives us correct historyEventId' );
is( $h->get('userId'),         $user->userId,      '..and correct userId' );
is( $h->get('assetId'),         undef,      '..and correct assetId' );
cmp_deeply( $h->get('data'), { test => 'abc' }, '..and correct (deserialised) data' );

###
# WebGUI::History->update
$h->update( { historyEventId => 'TESTTEST' } );
is( $h->get('historyEventId'), 'TESTTEST', 'we can set something' );
$h->update( { historyEventId => 'TEST' } );    # restore previous value

###
# WebGUI::History->dataSuperHashOf

ok( $h->dataSuperHashOf( { test => 'abc' } ), 'dataSuperHashOf finds our row with identical spec' );
ok( $h->dataSuperHashOf( {} ), '.. and with empty spec' );
ok( !$h->dataSuperHashOf( { test  => 'abcd' } ), 'And ignores with incorrect spec value' );
ok( !$h->dataSuperHashOf( { testX => 'abc' } ),  '..and incorect spec value' );
ok( !$h->dataSuperHashOf( { test => 'abc', a => 1, b => 2 } ), '..and too specific spec' );

## with afterAllHistoryEventId param..
#
## push $h into the past (it probably has same timestamp as $h2)
## n.b. that Crud won't let us update dateCreated via ->update so we need to write direct to db
#my $dateCreated = WebGUI::DateTime->new( $session, $h->get('dateCreated') );
#$dateCreated->add( seconds => -10 );
#$session->db->write( "update history set dateCreated = ? where historyId = ?", [ $dateCreated, $h->getId ] );
#
#cmp_deeply(
#    [   WebGUI::History->all(
#            $session, { userId => 4, historyEventId => 'TEST', afterAllHistoryEventId => 'non-existent' }
#        )
#    ],
#    [ $h->getId ],
#    'afterAllHistoryEventId has no effect if event doesnt exist'
#);
#cmp_deeply(
#    [   WebGUI::History->all(
#            $session, { userId => 4, historyEventId => 'TEST2', afterAllHistoryEventId => 'non-existent' }
#        )
#    ],
#    [ $h2->getId ],
#    '..and same for TEST2'
#);
#cmp_deeply(
#    [   WebGUI::History->all(
#            $session, { userId => 4, historyEventId => 'TEST', afterAllHistoryEventId => 'TEST2' }
#        )
#    ],
#    [],
#    '..but we get no results if the afterEvent appears later that our first event'
#);
#cmp_deeply(
#    [   WebGUI::History->all(
#            $session, { userId => 4, historyEventId => 'TEST2', afterAllHistoryEventId => 'TEST' }
#        )
#    ],
#    [ $h2->getId ],
#    '..and we get our second event if we reverse the situation'
#);
#$h2->update( { historyEventId => 'TEST' } );
#cmp_deeply(
#    [ WebGUI::History->all( $session, { userId => 4, historyEventId => 'TEST' } ) ],
#    [ $h->getId, $h2->getId ],
#    'all gives us both, in correct dateCreated order'
#);

###
# WebGUI::History->mostRecent
cmp_deeply( WebGUI::History->mostRecent( $session, { userId => $user->userId, historyEventId => 'TEST' } ),
    $h2, '..but mostRecent only gives us later one' );
is( WebGUI::History->mostRecent( $session, { userId => $user->userId, historyEventId => 'blah' } ),
    undef, '..and empty set handled correctly' );
cmp_deeply( WebGUI::History->mostRecent($session), $h2, '..and without options we get same (latest) one' );

#####
# Preserve History
####
{
# 
    is($user->preserveHistory, undef, 'By default, User History disappears when user deleted');
    ok(WebGUI::History->mostRecent($session, { userId => $user->userId }), 'User has history');
    $user->delete;
    is(WebGUI::History->mostRecent($session, { userId => $user->userId }), undef, 'User history now gone');

    # Let's preserve it instead..
    $user = WebGUI::User->new($session, 'new');
    WebGUI::Test->usersToDelete($user);
    my $h = WebGUI::History->create(
        $session,
        {   historyEventId => 'TEST',
            userId         => $user->userId,
            data           => { test => 'preserve this' }
        }
    );
    ok(WebGUI::History->mostRecent($session, { userId => $user->userId }), 'User has history again');
    $user->preserveHistory(1);
    is($user->preserveHistory, 1, 'User now set to preserve history');
    $user->delete;
    ok(WebGUI::History->mostRecent($session, { userId => $user->userId }), '..and this time it remains');
    $h->delete;
}

END {
    $h->delete()  if $h;
    $h2->delete() if $h2;
    $h3->delete() if $h3;
}
