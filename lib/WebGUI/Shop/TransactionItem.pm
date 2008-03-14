package WebGUI::Shop::TransactionItem;

use strict;
use Class::InsideOut qw{ :std };
use JSON;
use WebGUI::DateTime;
use WebGUI::Exception::Shop;

=head1 NAME

Package WebGUI::Shop::TransactionItem

=head1 DESCRIPTION

Each transaction item represents a sku that was purchased or attempted to be purchased.

=head1 SYNOPSIS

 use WebGUI::Shop::TransactionItem;

 my $item = WebGUI::Shop::TransactionItem->new($transaction);

=head1 METHODS

These subroutines are available from this package:

=cut

readonly transaction => my %transaction;
private properties => my %properties;

#-------------------------------------------------------------------

=head2 create ( transaction, properties)

Constructor. Adds an item to the transaction. Returns a reference to the item.

=head3 transaction

A reference to WebGUI::Shop::Transaction object.

=head3 properties

See update() for details.

=cut

sub create {
    my ($class, $transaction, $properties) = @_;
    unless (defined $transaction && $transaction->isa("WebGUI::Shop::Transaction")) {
        WebGUI::Error::InvalidObject->throw(expected=>"WebGUI::Shop::Transaction", got=>(ref $transaction), error=>"Need a transaction.");
    }
    unless (defined $properties && ref $properties eq "HASH") {
        WebGUI::Error::InvalidParam->throw(param=>$properties, error=>"Need a properties hash reference.");
    }
    my $itemId = $transaction->session->id->generate;
    $transaction->session->db->write('insert into transactionItem (itemId, transactionId) values (?,?)', [$itemId, $transaction->getId]);
    my $self = $class->new($transaction, $itemId);
    $self->update($properties);
    return $self;
}

#-------------------------------------------------------------------

=head2 delete ( )

Removes this item from the transaction.

=cut

sub delete {
    my $self = shift;
    $self->transaction->session->db->deleteRow("transactionItem","itemId",$self->getId);
    undef $self;
    return undef;
}

#-------------------------------------------------------------------

=head2 get ( [ property ] )

Returns a duplicated hash reference of this object’s data.

=head3 property

Any field − returns the value of a field rather than the hash reference.

=cut

sub get {
    my ($self, $name) = @_;
    if (defined $name) {
        if ($name eq "options") {
            my $options = $properties{id $self}{$name};
            if ($options eq "") {
                return {};
            }
            else {
                return JSON::from_json($properties{id $self}{$name});
            }
        }
        return $properties{id $self}{$name};
    }
    my %copyOfHashRef = %{$properties{id $self}};
    return \%copyOfHashRef;
}

#-------------------------------------------------------------------

=head2 getId () 

Returns the unique id of this item.

=cut

sub getId {
    my $self = shift;
    return $self->get("itemId");
}


#-------------------------------------------------------------------

=head2 getSku ( )

Returns an instanciated WebGUI::Asset::Sku object for this item.

=cut

sub getSku {
    my ($self) = @_;
    my $asset = WebGUI::Asset->newByDynamicClass($self->transaction->session, $self->get("assetId"));
    $asset->applyOptions($self->get("options"));
    return $asset;
}


#-------------------------------------------------------------------

=head2 new ( transaction, itemId )

Constructor.  Instanciates a transaction item based upon itemId.

=head3 transaction

A reference to the current transaction

=head3 itemId

The unique id of the item to instanciate.

=cut

sub new {
    my ($class, $transaction, $itemId) = @_;
    unless (defined $transaction && $transaction->isa("WebGUI::Shop::Transaction")) {
        WebGUI::Error::InvalidObject->throw(expected=>"WebGUI::Shop::Transaction", got=>(ref $transaction), error=>"Need a transaction.");
    }
    unless (defined $itemId) {
        WebGUI::Error::InvalidParam->throw(error=>"Need an itemId.");
    }
    my $item = $transaction->session->db->quickHashRef('select * from transactionItem where itemId=?', [$itemId]);
    if ($item->{itemId} eq "") {
        WebGUI::Error::ObjectNotFound->throw(error=>"Item not found.", id=>$itemId);
    }
    if ($item->{transactionId} ne $transaction->getId) {
        WebGUI::Error::ObjectNotFound->throw(error=>"Item not in this transaction.", id=>$itemId);
    }
    my $self = register $class;
    my $id        = id $self;
    $transaction{ $id }   = $transaction;
    $properties{ $id } = $item;
    return $self;
}


#-------------------------------------------------------------------

=head2 transaction ( )

Returns a reference to the transaction object.

=cut


#-------------------------------------------------------------------

=head2 update ( properties )

Sets properties of the transaction item.

=head3 properties

A hash reference that contains one of the following:

=head4 item

A reference to a WebGUI::Shop::CartItem. Alternatively you can manually pass in any of the following
fields that would be created automatically by this object: assetId configuredTitle options shippingAddressId
shippingName shippingAddress1 shippingAddress2 shippingAddress3 shippingCity shippingState shippingCountry
shippingCode shippingPhoneNumber quantity price

=head4 shippingTrackingNumber

A tracking number that is used by the shipping method for this transaction.

=head4 shippingStatus

The status of this item. The default is 'NotShipped'. Other statuses include: Cancelled, BackOrdered, Shipped

=cut

sub update {
    my ($self, $newProperties) = @_;
    my $id = id $self;
    if (exists $newProperties->{item}) {
        my $item = $newProperties->{item};
        my $sku = $item->getSku;
        $newProperties->{options} = $sku->getOptions;
        $newProperties->{assetId} = $sku->getId;       
        $newProperties->{price} = $sku->getPrice;       
        $newProperties->{configuredTitle} = $sku->getConfiguredTitle;
        my $address = $item->getShippingAddress;
        $newProperties->{shippingAddressId} = $address->getId;
        $newProperties->{shippingAddressName} = $address->get('name');
        $newProperties->{shippingAddress1} = $address->get('address1');
        $newProperties->{shippingAddress2} = $address->get('address2');
        $newProperties->{shippingAddress3} = $address->get('address3');
        $newProperties->{shippingCity} = $address->get('city');
        $newProperties->{shippingState} = $address->get('state');
        $newProperties->{shippingCountry} = $address->get('country');
        $newProperties->{shippingCode} = $address->get('code');
        $newProperties->{shippingPhoneNumber} = $address->get('phoneNumber');
        $newProperties->{quantity} = $item->get('quantity');
    }
    my @fields = (qw(assetId configuredTitle options shippingAddressId shippingTrackingNumber shippingStatus
        shippingName shippingAddress1 shippingAddress2 shippingAddress3 shippingCity shippingState
        shippingCountry shippingCode shippingPhoneNumber quantity price));
    foreach my $field (@fields) {
        $properties{$id}{$field} = (exists $newProperties->{$field}) ? $newProperties->{$field} : $properties{$id}{$field};
    }
    if (exists $newProperties->{options} && ref($newProperties->{options}) eq "HASH") {
        $properties{$id}{options} = JSON::to_json($newProperties->{options});
    }
    if (exists $newProperties->{shippingStatus}) {
        $properties{$id}{shippingDate} = WebGUI::DateTime->new($self->transaction->session,time())->toDatabase;
    }
    $self->transaction->session->db->setRow("transactionItem","itemId",$properties{$id});
}


1;
