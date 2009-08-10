package WebGUI::History;

=head1 NAME

WebGUI::History

=head1 DESCRIPTION

Adds a mechanism for recording and accessing user History

=cut

use strict;
use JSON;
use Params::Validate qw(:all);
use Test::Deep::NoTest;
use base 'WebGUI::Crud';
use Class::InsideOut qw( public readonly private register id );
Params::Validate::validation_options( on_fail => sub { WebGUI::Error::InvalidParam->throw( error => shift ) } );

private asset => my %asset;
private user  => my %user;

=head2 crud_definition

Overrides WebGUI::Crud::crud_definition

=cut

sub crud_definition {
    my $class = shift;
    my ($session) = validate_pos( @_, { isa => 'WebGUI::Session' } );
    my $definition = $class->SUPER::crud_definition($session);
    $definition->{tableName} = 'history';
    $definition->{tableKey}  = 'historyId';
    my $properties = $definition->{properties};

    # History events are typically classified via a GUID
    $properties->{historyEventId} = { fieldType => 'Guid' };
    
    # ..and often bound to a userId..
    $properties->{userId} = { fieldType => 'User' };

    # ..and also to an assetId..
    $properties->{assetId} = { fieldType => 'Asset' };

    # ..and anything else can go into the serialised 'data'
    $properties->{data} = {
        fieldType    => 'Textarea',
        defaultValue => {},
        serialize    => 1,
    };

    return $definition;
}

#-------------------------------------------------------------------

=head2 asset

Returns the associated L<WebGUI::Asset> object

=cut

sub asset {
    my $self = shift;

    $asset{ id $self}
        or $asset{ id $self} = do {
        WebGUI::Asset->new( $self->session, $self->get('assetId') );
        }
}

#-------------------------------------------------------------------

=head2 user

Returns the associated L<WebGUI::User> object

=cut

sub user {
    my $self = shift;

    $user{ id $self}
        or $user{ id $self} = do {
        WebGUI::User->new( $self->session, $self->get('userId') );
        }
}

=head2 mostRecent ($session, $options)

Convenience method that returns the most recent History object for the given user

Has the same signature as L<WebGUI::Crud::getAllSql>, plus the following extra options:

=over 4

=item userId

=item historyEventId

=item assetId

=back

=cut

sub mostRecent {
    my $class = shift;
    my ( $session, $options )
        = validate_pos( @_, { isa => 'WebGUI::Session' }, { type => HASHREF, default => {} } );

    $options->{limit}   = 1;
    $options->{orderBy} = 'dateCreated desc';

    for my $opt qw(userId assetId historyEventId) {
        next unless defined $options->{$opt};
        push @{ $options->{constraints} }, { "$opt = ?" => $options->{$opt} };
        delete $options->{$opt};
    }
    my $mostRecent = __PACKAGE__->getAllIterator( $session, $options )->();
    return unless $mostRecent;
    return $mostRecent;
}

=head2 dataSuperHashOf

Returns true/false depending on whether the data hash matches the given criteria.

See L<Test::Deep::superhashof> for details.

=cut

sub dataSuperHashOf {
    my $self = shift;
    my ($spec) = validate_pos( @_, { type => HASHREF } );

    return eq_deeply( $self->get('data'), superhashof($spec) );
}

1;
