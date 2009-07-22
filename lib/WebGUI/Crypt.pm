package WebGUI::Crypt;

use strict;
use warnings;
use Tie::IxHash;
use Class::InsideOut qw{ :std };
use WebGUI::Exception;
use WebGUI::Pluggable;
use English qw( -no_match_vars );
use List::MoreUtils qw(uniq);
use Data::Dumper;
use Params::Validate qw(:all);
Params::Validate::validation_options( on_fail => sub { WebGUI::Error::InvalidParam->throw( error => shift ) } );

=head1 NAME

WebGUI::Crypt

=head1 DESCRIPTION

Package for interfacing with Crypt provider.

=head1 SYNOPSIS

 use WebGUI::Crypt;

 my $crypt = WebGUI::Crypt->new($session);
 my $crypt2 = $session->crypt;
 my $ciphertext = $crypt->encrypt("Plain Text");
 my $plaintext = $crypt->decrypt($ciphertext);

=head1 METHODS

These methods are available from this package:

=cut

# InsideOut object properties
readonly session    => my %session;       # WebGUI::Session object
private providers   => my %providers;
private providerIdCache => my %providerIdCache; # A private cache of providerIds (keyed by {table}{field})

#-------------------------------------------------------------------

=head2 new ( session )

Constructor. You should not need to call this normally, see L<WebGUI::Session::crypt>.

=head3 session

A reference to the current session.

=cut

sub new {
    my ( $class, $session ) = @_;

    # Check arguments..
    if ( !defined $session || !$session->isa('WebGUI::Session') ) {
        WebGUI::Error::InvalidParam->throw(
            param => $session,
            error => 'Need a session.'
        );
    }

    # Register Class::InsideOut object..
    my $self = register $class;

    # Initialise object properties..
    my $id = id $self;
    $session{$id} = $session;
    return $self;
}

#-------------------------------------------------------------------

=head2 _getProvider ( $args )

Returns the correct provider, creating the object if required

=head3 $args

Hash ref containing a 'providerId' or a 'table' and 'field' in the providers table

=cut

sub _getProvider {
    my ( $self, $args ) = @_;

    if ( ref $args ne 'HASH' ) {
        WebGUI::Error::InvalidParam->throw(
            param => $args,
            error => 'getProvider requires a hash ref be passed in with a providerI or table/field combo.'
        );
    }

    # Provider id is either passed in, or we look it up, or it defaults to None
    my $providerId = $args->{providerId} || $self->lookupProviderId($args) || 'None';

    # Try looking up provider in cache
    if (my $provider = $providers{ id $self}->{$providerId}) {
        return $provider;
    }

    # Otherwise, let's instantiate it..
    my $providerData = $session{ id $self}->config->get("crypt")->{$providerId} or
        WebGUI::Error::InvalidParam->throw(
            param => $args,
            error => "WebGUI::Crypt provider not found in site config: $providerId"
        );
    $providerData->{providerId} = $providerId;
    my $providerClass = $providerData->{provider};
    
    # Try loading the Provider..
    eval { WebGUI::Pluggable::load($providerClass) };
    if ( Exception::Class->caught() ) {
        WebGUI::Error::Pluggable::LoadFailed->throw(
            error  => $EVAL_ERROR,
            module => $providerClass,
        );
    }

    # Instantiate the Provider..
    my $provider;
    eval { $provider = $providerClass->new( $session{ id $self}, $providerData ) };
    if ( Exception::Class->caught() ) {
        WebGUI::Error::Pluggable::RunFailed->throw(
            error      => $EVAL_ERROR,
            module     => $providerClass,
            subroutine => 'new',
            params     => [ $session{ id $self}, $args ],
        );
    }

    # Store the provider as a member for later resuse..
    $providers{ id $self}->{$providerId} = $provider;

    return $provider;
}

#-------------------------------------------------------------------

=head2 lookupProviderId ( $args )

Takes a table and field and returns the correct providerId

=head3 $args

Hash ref containing a 'table' and 'field' in the providers table

=cut

sub lookupProviderId {
    my $self = shift;
    my %opts = validate(@_, { table => 1, field => 1 });
    
    my $table = $opts{table};
    my $field = $opts{field};
    
    # If we have already looked up table/field combination, return it
    # N.B. we deliberately do this even if the result is undef (otherwise
    # we've be doing a db check on every single lookup)
    if (exists $providerIdCache{ id $self}->{ $table }->{ $field }) {
        return $providerIdCache{ id $self}->{ $table }->{ $field };
    }

    my $providerId
        = $self->session->db->quickScalar(
        "select providerId from cryptFieldProviders where `table` = ? and `field` = ?",
        [ $table, $field ] );
        
    if (!$providerId) {
        # This is quite normal - most tables will not be using Crypt hence they won't have
        # an entry in the cryptFieldProviders table
        $self->session->log->debug("ProviderId not found for table: $table, field: $field");
    }
    
    # Cache the result (including if the provider was not found - see above)
    $self->cacheProviderId( table => $table, field => $field, providerId => $providerId );
    
    return $providerId;
}

#-------------------------------------------------------------------

=head2 cacheProviderId ( $args )

Caches a providerId corresponding to a table and field

=head3 $args

Hash ref containing a 'table' and 'field' and a providerId to cache

=cut

sub cacheProviderId {
    my $self = shift;
    my %opts = validate(@_, { table => 1, field => 1, providerId => 1 });
    $providerIdCache{ id $self}->{ $opts{table} }->{ $opts{field} } = $opts{providerId};
}

#-------------------------------------------------------------------

=head2 isEnabled

Returns true if globle encryption is not enabled

=cut 

sub isEnabled {
    my ($self) = @_;
    return $session{ id $self}->setting->get('cryptEnabled');
}

#-------------------------------------------------------------------

=head2 getProviders

Returns a hashref of providerId to provider name.

=cut 

sub getProviders {
    my $self = shift;
    my $cryptConfig = $self->session->config->get('crypt');
    my %providers = map { $_, $self->session->config->get('crypt')->{$_}->{'name'} } keys %$cryptConfig;
    return \%providers;
}

#-------------------------------------------------------------------

=head2 encrypt ( $plaintext, $args )

Encrypt some plaintext

=head3 $plaintext

This is the string to be encrypted

=head3 $args

This is a hash ref which must contain a 'providerId' or a 'table' and 'field' in the providers table

=cut

sub encrypt {
    my ( $self, $plaintext, $args ) = @_;
    return unless $self->isEnabled;
    my $provider = $self->_getProvider($args);
    my $providerId = $provider->providerId;
    return $plaintext if $providerId eq 'None';
    return join ':', ('CRYPT', $providerId, $provider->encrypt($plaintext));
}

#-------------------------------------------------------------------

=head2 encrypt_hex ( $plaintext, $args )

Same as L<encrypt>, but returns hex-encoded encrypted string

=cut

sub encrypt_hex {
    my ( $self, $plaintext, $args ) = @_;
    return unless $self->isEnabled;
    my $provider = $self->_getProvider($args);
    my $providerId = $provider->providerId;
    return $plaintext if $providerId eq 'None';
    return join ':', ('CRYPT', $providerId, unpack('H*', $provider->encrypt($plaintext)));
}

#-------------------------------------------------------------------

=head2 decrypt ( $ciphertext )

Decrypt some ciphertext

=cut

sub decrypt {
    my ( $self, $ciphertext ) = @_;
    return unless defined $ciphertext;
    return $ciphertext unless $self->isEnabled;
    my ( $providerId, $text ) = $self->parseHeader($ciphertext);
    return $text if $providerId eq 'None';
    return $self->_getProvider( { providerId => $providerId } )->decrypt($text);
}

#-------------------------------------------------------------------

=head2 decrypt_hex ( $ciphertext )

Same as L<decrypt>, but expects hex-encoded encrypted string

=cut

sub decrypt_hex {
    my ( $self, $ciphertext ) = @_;
    return unless defined $ciphertext;
    return $ciphertext unless $self->isEnabled;
    my ( $providerId, $text ) = $self->parseHeader($ciphertext);
    return $text if $providerId eq 'None';
    return $self->_getProvider( { providerId => $providerId } )->decrypt(pack('H*', $text));
}

#-------------------------------------------------------------------

=head2 parseHeader ( $ciphertext )

Parse ciphertext header, which, if valid, looks like CRYPT:providerId:encrypted_text

Returns the array: ( providerId, encrypted_text )

=cut

sub parseHeader {
    my ( $self, $ciphertext ) = @_;
    # Use split as opposed to a regex for speed
    my ($CRYPT, $providerId, $text) = split ':', $ciphertext, 3;
    if ($CRYPT && $CRYPT eq 'CRYPT' && $providerId) {
        return ( $providerId, $text );
    } else {
        return ( 'None', $ciphertext );
    }
}

#-------------------------------------------------------------------

=head2 setProvider ( $arg_ref )

Allows client code to set providers for tables/fields.

This is called by client code when the user asks to change the provider for an 
encryptable field (for example, when user selects from "Encrypt with.." drop-down list 
in User Profiling)

=head3 arg_ref

This is a hash ref that must contain $table, $field, $key, $providerId

=over 3

=item *

table and field uniquely identify the encryptable field

=item *

key is a unique column in $table that can be used to identify individual rows. This is required
so that the CryptUpdateFieldProviders workflow can write data to the database row by row.

=item *

providerId records the currently chosen provider for the field

=back

=cut

sub setProvider {
    my ( $self, $arg_ref ) = @_;
    return unless $self->isEnabled;
    if (   ref $arg_ref ne 'HASH'
        || !$arg_ref->{table}
        || !$arg_ref->{field}
        || !$arg_ref->{key}
        || !$arg_ref->{providerId} )
    {
        WebGUI::Error::InvalidParam->throw(
            param => $arg_ref,
            error => 'setProvider requires a hash ref be passed in with $table, $field, $key, and $providerId.'
        );
    }
    
    my $newProviderId = $arg_ref->{providerId};
    
    # activeProviderIds is a comma-separated list of all providers for which encrypted data may 
    # currently exist in the system (for the given table,field combination)
    my ($currentProviderId, $activeProviderIds) 
        = $self->session->db->quickArray(
        "select providerId, activeProviderIds from cryptFieldProviders where `table` = ? and `field` = ?",
        [ $arg_ref->{table}, $arg_ref->{field} ] );
    
    if ( !$currentProviderId ) {
        # If no row found:
        # * assume current and only active provider is 'None'
        # * add a new row with providerId set to the $newProviderId and activeProviderIds set 
        #   to 'None,newProviderId' to indicate that the db field may contain data encrypted 
        #   with both 'None' and the newly chosen provider 
        $self->session->db->write(
            "insert into cryptFieldProviders values(?,?,?,?,?)",
            [   $arg_ref->{table},      
                $arg_ref->{field}, 
                $arg_ref->{key},
                $newProviderId, 
                mergeActiveProviderIds( 'None', $newProviderId),
            ]
        );
    }
    elsif ($currentProviderId ne $newProviderId) {
        # If row found, append existing providerId to activeProviderIds list and set providerId 
        # to $newProviderId (even if $newProviderId is 'None')
        $self->session->db->write(
            "update cryptFieldProviders set providerId = ?, activeProviderIds = ? where `table` = ? and `field` = ?",
            [ 
                $newProviderId, 
                mergeActiveProviderIds( $activeProviderIds, $newProviderId),
                $arg_ref->{table}, 
                $arg_ref->{field},
            ]
        );
    }
    
    # Update the providerId cache
    $self->cacheProviderId( table => $arg_ref->{table}, field => $arg_ref->{field}, providerId => $newProviderId );
    
    # Trigger the workflow (if necessary)
    if ($self->session->setting->get('cryptTriggerUpdateOnProviderChange')) {
        WebGUI::Crypt->startCryptWorkflow( $session{ id $self} );
    }
    
    return 1;
}

=head2 mergeActiveProviderIds ($activeProviderIds, $newProviderId)

Merges a new activeProviderId into a list of activeProviderIds. Returns a new comma-separated list,
with the new providerId appended, and all duplicates removed.

=head3 activeProviderIds

A comma-separated list of providerIds

=head3 newProviderId

A new providerId to add

=cut

sub mergeActiveProviderIds {
    my ($activeProviderIds, $newProviderId) = @_;
    
    # Active Providers are comma-separated
    my @activeProviderIds = split q{,}, $activeProviderIds;
    
    # Add the new provider to the list (even if it already is on the list)
    push @activeProviderIds, $newProviderId;
    
    # Get new comma-separated list (with duplicates removed)
    return join q{,}, (uniq @activeProviderIds);
}

#-------------------------------------------------------------------

=head2 startCryptWorkflow ( $session )

For directly starting the crypt workflow.

=head3 session

The WebGUI::Session object

=cut

sub startCryptWorkflow {
    my $class = shift;
    my ($session) = @_;

    my $workflow = WebGUI::Workflow->new($session, 'CryptProviders00000001') or do {
        my $error = "The CryptProviders00000001 workflow has been deleted.  Please contact an Administrator immediately.";
        $session->log->error($error);
        return $error;
    };
    
    my $instance = WebGUI::Workflow::Instance->create($session, {
        workflowId => $workflow->getId,
        priority   => 1,
    }) or do {
        my $error;
        if ($session->stow->get('singletonWorkflowClash')) {
            $error = "The Update Crypt Providers workflow is already running.";
        } else {
            $error = "Error creating the workflow instance.";
        }
        $session->log->error($error);
        return $error;
    };
    $instance->run();

    return "Workflow Started";
}
1;
