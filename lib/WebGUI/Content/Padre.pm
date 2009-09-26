package WebGUI::Content::Padre;

use strict;
use JSON;

=head1 NAME

Package WebGUI::Content::Padre

=head1 DESCRIPTION

Handle all requests for communicating with Padre

=cut

#-------------------------------------------------------------------

=head2 handler ( session ) 

The content handler for this package.

=cut

sub handler {
    my ($session) = @_;
    my $output = undef;
    return undef unless $session->form->get('op') eq 'padre';
    
    # User must be logged in
    return $session->privilege->noAccess if $session->user->userId eq '1';
    
    # Set header so that Padre can detect site-support
    $session->request->headers_out->set('Padre-Plugin-WebGUI' => 0.02);
    
    my $func = $session->form->get( 'func' ) || 'list';
    $func = "www_$func";
    
    if (WebGUI::Content::Padre->can($func)) {
        return WebGUI::Content::Padre->$func($session);
    } else {
        return error($session, "Invalid func: $func");
    }
}

sub error {
    my $session = shift;
    my $error = shift;
    $session->http->setStatus("400", "Bad Request");
    $session->log->error($error);
    $session->log->preventDebugOutput;
    return "ERROR: $error";
}

sub www_list {
    my $class = shift;
    my $session = shift;
    
    my $root = WebGUI::Asset->getRoot($session);
    my $assets = $root->getLineage( [ "self", "descendants" ], { returnObjects => 1 } );
    
    # Build a hash mapping each assetId to an array of children for that asset
    my %tree;
    foreach my $asset (@$assets) {
        next unless $asset->canView;
        
        # Add this new asset to the tree, initially with no children
        $tree{ $asset->getId } = [];
        
        # Push this asset onto its parent's list of children
        push @{ $tree{ $asset->get('parentId') } }, $asset;
    }

    # Serialise the tree and turn it into a recursive tree hash as requried by update_treectrl
    my $serialise;
    $serialise = sub {
        my $asset = shift or return;
        my $node = $class->serialise_minimal( $asset );
        
        # Recursively serialise children and add to node's children property
        push( @{ $node->{children} }, $serialise->($_) ) for @{ $tree{ $asset->getId } };
        return $node;
    };

    return $class->as_json( $session, $serialise->($root)->{children} );
}

sub www_edit {
    my $class = shift;
    my $session = shift;
    
    my $assetId = $session->form->param('assetId') or return error($session, "assetId not provided");
    
    my $asset = WebGUI::Asset->new($session, $assetId) or return error($session, "Unable to instantiate asset: $assetId");
    
    return error($session, "Permission Denied (canEdit)") unless $asset->canEdit;
    
    return $class->as_json($session, $class->serialise( $asset ) );
}

sub www_save {
    my $class = shift;
    my $session = shift;
    
    my $assetId = $session->form->param('assetId') or return error($session, "assetId not provided");
    my $props = $session->form->param('props') or return error($session, "props not provided");
    
    my $asset = WebGUI::Asset->new($session, $assetId) or return error($session, "Unable to instantiate asset: $assetId");
    
    return error($session, "Permission Denied (canEdit)") unless $asset->canEdit;
    
    $props = eval { from_json($props) };
    if ($@) {
        $session->log->warn($@);
        return error($session, "Invalid props");
    }
    
    my $version_tag = WebGUI::VersionTag->getWorking( $session );
    $version_tag->set( { name => 'Padre Asset Editor' } );
    
    $asset->update($class->deserialise( $asset, $props ));
    
    $version_tag->commit;
    
    return $class->as_json($session, $class->serialise( $asset ) );
}

sub serialise_minimal {
    my $class = shift;
    my $asset = shift;
    
    return {
        assetId => $asset->getId,
        className => $asset->get('className'),
        menuTitle => $asset->getMenuTitle,
        revisionDate => $asset->get('revisionDate'),
        url  => $asset->getUrl,
        icon => $asset->getIcon,
    };
}

sub serialise {
    my $class = shift;
    my $asset = shift;
    
    my $data = $class->serialise_minimal( $asset );
    
    # By default, put 'description' into content field
    $data->{content} = $asset->get('description');
    
    # Hook in more specific Asset-handling here
    if ($asset->isa('WebGUI::Asset::Template')) {
        $data->{content} = $asset->get('template');
    }
    if ($asset->isa('WebGUI::Asset::Snippet')) {
        $data->{content} = $asset->get('snippet');
        $data->{mimetype} = $asset->get('mimeType');
    }
    return $data;
}

sub deserialise {
    my $class = shift;
    my $asset = shift;
    my $data = shift;
    
    # Hook in more specific Asset-handling here
    my $content = delete $data->{content};
    delete $data->{className};
    
    if ($asset->isa('WebGUI::Asset::Template')) {
        $data->{template} = $content;
    } elsif ($asset->isa('WebGUI::Asset::Snippet')) {
        $data->{snippet} = $content;
    } else {
        # By default, put 'content' back into 'description'
        $data->{description} = $content;
    }
    return $data;
}

sub as_json {
    my $class = shift;
    my $session = shift;
    my $data = shift;
    $session->http->setMimeType('application/json');
    return to_json( $data );
}

1;
