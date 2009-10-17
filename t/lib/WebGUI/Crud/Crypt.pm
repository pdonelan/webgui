package WebGUI::Crud::Crypt;

# Crud subclass for testing's Crud's crypt option

use base qw/WebGUI::Crud/;

sub crud_definition {
    my ( $class, $session ) = @_;
    my $definition = $class->SUPER::crud_definition($session);
    $definition->{tableName}   = 'crudCrypt';
    $definition->{tableKey}    = 'crudCryptId';
    $definition->{sequenceKey} = '';
    my $properties = $definition->{properties};
    $properties->{secret} = {
        fieldType       => 'text',
        defaultValue    => 'openseasame',
        crypt           => 1,
    };
    $properties->{secretJson} = {
        fieldType       => 'textarea',
        defaultValue    => [],
        serialize       => 1,
        crypt           => 1,
    };
    return $definition;
}

1;
