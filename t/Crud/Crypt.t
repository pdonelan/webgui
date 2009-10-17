# vim:syntax=perl
#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2009 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#------------------------------------------------------------------

# Tests WebGUI::Crud's Crypt option

use FindBin;
use strict;
use lib "$FindBin::Bin/../lib";
use Test::More;
use Test::Deep;
use JSON;
use WebGUI::Test;    # Must use this before any other WebGUI modules
use WebGUI::Session;

my $session = WebGUI::Test->session;
plan tests => 23;
use_ok('WebGUI::Crud::Crypt');

WebGUI::Crud::Crypt->crud_createTable($session);

# Crypt provider defaults to None
for my $field qw(secret secretJson) {
    is( WebGUI::Crud::Crypt->crud_getCryptProviderId( $session, $field ),
        undef,
        "Crypt provider defaults to undef, which is the same as None"
    );
}

# Set the provider
WebGUI::Crud::Crypt->crud_setCryptProviderId($session, { field => 'secret', providerId => 'SimpleTest' } );
WebGUI::Crud::Crypt->crud_setCryptProviderId($session, { field => 'secretJson', providerId => 'SimpleTest' } );

# Crud should have set the crypt provider for us, according to WebGUI::Crud::Crypt's definition
for my $field qw(secret secretJson) {
    is( WebGUI::Crud::Crypt->crud_getCryptProviderId( $session, $field ),
        'SimpleTest',
        "Crypt provider set on field $field"
    );
}

my $c = WebGUI::Crud::Crypt->create($session);
isa_ok( $c, 'WebGUI::Crud::Crypt' );
cmp_deeply(
    $c->get,
    {   secret         => 'openseasame',
        secretJson     => [],
        dateCreated    => ignore(),
        lastUpdated    => ignore(),
        sequenceNumber => ignore(),
        crudCryptId    => ignore(),
    },
    'default values set correctly (and transparently decrypted)'
);

# The actual data in the db should be encrypted
for my $field qw(secret secretJson) {
    like( $session->db->quickScalar( "select `$field` from crudCrypt where crudCryptId=?", [ $c->getId ] ),
        qr/^CRYPT:SimpleTest:/, "Field $field really is encrypted in the db" );
}

$c->update( { secret => 'wallah wallah bing bang', secretJson => { ooh => 'ee', oh => 'ah ah' } } );
is( $c->get('secret'), 'wallah wallah bing bang', 'Update works just fine' );
cmp_deeply( $c->get('secretJson'), { ooh => 'ee', oh => 'ah ah' }, 'Serialised data works too' );

# Check data is still encrypted
for my $field qw(secret secretJson) {
    like( $session->db->quickScalar( "select `$field` from crudCrypt where crudCryptId=?", [ $c->getId ] ),
        qr/^CRYPT:SimpleTest:/, "Field $field is still encrypted in the db" );
}

my $c2 = WebGUI::Crud::Crypt->new( $session, $c->getId );
cmp_deeply( $c2->get('secretJson'), { ooh => 'ee', oh => 'ah ah' }, 'Constructor works' );

# Try changing the provider
WebGUI::Crud::Crypt->crud_setCryptProviderId($session, { field => 'secret', providerId => 'SimpleTest2' } );
is( WebGUI::Crud::Crypt->crud_getCryptProviderId( $session, 'secret'), 'SimpleTest2', "New crypt provider now in use");
is( WebGUI::Crud::Crypt->crud_getCryptProviderId( $session, 'secretJson'), 'SimpleTest', "..but other field unchanged");

# Rows in db still using old provider (both fields)
for my $field qw(secret secretJson) {
    like( $session->db->quickScalar( "select `$field` from crudCrypt where crudCryptId=?", [ $c->getId ] ),
        qr/^CRYPT:SimpleTest:/, "Field $field crypt provider unchanged" );
}

# Create a new row - should use new provider for field: secret
my $c3 = WebGUI::Crud::Crypt->create($session);
isa_ok( $c3, 'WebGUI::Crud::Crypt' );
like( $session->db->quickScalar( "select secret from crudCrypt where crudCryptId=?", [ $c3->getId ] ), qr/^CRYPT:SimpleTest2:/, "Field secret now using new field provider" );
like( $session->db->quickScalar( "select secretJson from crudCrypt where crudCryptId=?", [ $c3->getId ] ), qr/^CRYPT:SimpleTest:/, "..whereas field secretJson still using unchanged provider" );

# Run crypt workflow to update old rows ($c) to use new provider
use WebGUI::Crypt;
WebGUI::Crypt->startCryptWorkflow($session);
wait_for_workflow($session, 'CryptProviders00000001');

like( $session->db->quickScalar( "select secret from crudCrypt where crudCryptId=?", [ $c->getId ] ), qr/^CRYPT:SimpleTest2:/, "Field secret now using new field provider" );
like( $session->db->quickScalar( "select secretJson from crudCrypt where crudCryptId=?", [ $c->getId ] ), qr/^CRYPT:SimpleTest:/, "..whereas field secretJson still using unchanged provider" );

#----------------------------------------------------------------------------
# Cleanup
END {
    WebGUI::Crud::Crypt->crud_dropTable($session);

}



=head2 wait_for_workflow

Waits for the specified workflow to finish before returning.

=cut

sub wait_for_workflow {
    my $session     = shift;
    my $workflow_id = shift;
    my $wf          = WebGUI::Workflow->new( $session, $workflow_id );
    my $maxwait     = 50;
    my $ctr         = 0;

    while ( my @instances = @{ $wf->getInstances() } ) {
        my $status = $instances[0]->get('lastStatus') || 'undefined';
        warn "Waiting for workflow: $workflow_id. Status $status. " . ( $maxwait - $ctr ) . " tries remaining.";
        return 0 if $ctr++ > $maxwait;
        sleep 1;
    }
    return 1;
}

#vim:ft=perl
