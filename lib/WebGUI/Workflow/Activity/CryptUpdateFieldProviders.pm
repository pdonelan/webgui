package WebGUI::Workflow::Activity::CryptUpdateFieldProviders;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2008 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use warnings;
use base 'WebGUI::Workflow::Activity';
use WebGUI::Asset;
use WebGUI::DateTime;
use DateTime::Duration;

=head1 NAME

Package WebGUI::Workflow::Activity::CryptUpdateFieldProviders

=head1 DESCRIPTION

This activity updates and re-encrypts encrypted fields with the currently chosen provider.

=head1 SYNOPSIS

See WebGUI::Workflow::Activity for details on how to use any activity.

=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------

=head2 definition ( session, definition )

See WebGUI::Workflow::Activity::defintion() for details.

=cut 

sub definition {
    my $class      = shift;
    my $session    = shift;
    my $definition = shift;
    my $i18n       = WebGUI::International->new( $session, "Workflow_Activity_CryptUpdateFieldProviders" );
    push(
        @{$definition},
        {   name       => $i18n->get("activityName"),
            properties => {}
        }
    );
    return $class->SUPER::definition( $session, $definition );
}

#-------------------------------------------------------------------

=head2 execute ( [ object ] )

Updates/re-encrypts encrypted fields with the currently chosen provider

Uses the activeProviderIds column in the cryptFieldProviders table to locate rows in the database that need
to be re-encrypted.

Each field is decrypted using whatever provider is specified in the field header.

This workflow has the very nice property that it can detect if the dataset changed under its feet, and if so 
re-process only the new data. It doesn't even mind if the user changes the field provider while it's running.. it 
will simply detect this and re-encrypt any data that doesn't use the new provider. Thus, this workflow can
be run safely with a website online.

=cut

sub execute {
    my $self    = shift;
    my $session = $self->session;

    # Record start date for Admin console
    $session->db->write( 'update cryptStatus set startDate=NOW(), userId=?, endDate=?, running=1',
        [ $session->user->userId, '' ] );

    my $endTime = time() + $self->getTTL();

    # We use the activeProviderIds column in the cryptFieldProviders table to locate rows in the database that need
    # to be re-encrypted. The activeProviderIds column is updated as we go, thus the following result set dwindles 
    # each time the workflow is allowed to execute..
    my $fieldProvidersSth = $session->db->read(
        "select `table`, `field`, `key`, providerId from cryptFieldProviders where activeProviderIds like ? order by `table`",
        ['%,%']
    );

    my $crypt = $session->crypt;
    my $cryptConfig = $self->session->config->get("crypt");
    FIELD_PROVIDER: 
    while ( my ( $table, $field, $key, $providerId ) = $fieldProvidersSth->array ) {
        # Each time we re-encrypt a field, it header gets updated to the new provider, thus
        # the following result set dwindles on each update:
        my $table_quoted = $session->db->dbh->quote_identifier($table);
        my $field_quoted = $session->db->dbh->quote_identifier($field);
        my $key_quoted = $session->db->dbh->quote_identifier($key);
        my $fieldSth = $session->db->read( "select $field_quoted, $key_quoted from $table_quoted where $field_quoted not like ?",
            ["CRYPT:$providerId:%"] );
        
        # Re-encrypt data one field at a time:
        while ( my ( $data, $uniqueKey ) = $fieldSth->array ) {
            $data = eval { $crypt->encrypt_hex( $crypt->decrypt_hex($data), { providerId => $providerId } ) };
            if ($@) {
                # For instance, if someone manually removed a crypt provider before re-encrypting all data
                # with another provider, WebGUI::Crypt wouldn't know how to decrypt the data
                $session->log->error(
                    "Error running Crypt Update Providers workflow for providerId: $providerId: $@");
                return $self->COMPLETE;
            }
            # Push back to the db, after which the row will no longer match $fieldSth resultset
            $session->db->write( "update $table_quoted set $field_quoted = ? where $key_quoted = ?", [ $data, $uniqueKey ] );
            
            # Give other workflows a chance to run
            return $self->WAITING(1) if ( time() > $endTime );
        }

        # We finished processing a field provider without timing out, check the dataset wasn't modified while we were working..
        # Need two types of queries, one for WebGUI::Crypt::None and one for all other provider types
        my $targetField = "CRYPT:$providerId:%";
        my $sql         = "select count(*) from $table_quoted where $field_quoted not like ?";
        if ( $cryptConfig->{$providerId}->{provider} eq "WebGUI::Crypt::None" ) {
            $targetField = "CRYPT:%";
            $sql         = "select count(*) from $table_quoted where $field_quoted like ?";
        }
        if ( $session->db->quickScalar( $sql, [$targetField] ) ) {
            # Dataset *did* change, so do another pass over $fieldSth (but only for the few rows that match)
            redo FIELD_PROVIDER;
        }
        else {
            # dataset now uses $providerId exclusively, so clear out activeProviderIds
            if ( $cryptConfig->{$providerId}->{provider} eq "WebGUI::Crypt::None" ) {
                # If new provider is None, we can remove the row altogether
                $session->db->write(
                "delete from cryptFieldProviders where `table` = ? and `field` = ?",
                [ $table, $field ] );
            } else {
                # otherwise, the activeProviderIds list contains only the new providerId
                $session->db->write(
                    "update cryptFieldProviders set activeProviderIds = ? where `table` = ? and `field` = ?",
                    [ $providerId, $table, $field ] );
            }
        }
    }
    
    # All done
    $session->db->write('update cryptStatus set endDate=NOW(), running=0');
    return $self->COMPLETE;
}

1;
