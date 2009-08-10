#!/usr/bin/env perl

# Script for turning on History

$|++;    # disable output buffering
our ( $webguiRoot, $configFile, $help, $man, $force, $demo, $quiet );

BEGIN {
    $webguiRoot = "..";
    unshift( @INC, $webguiRoot . "/lib" );
}

use strict;
use Pod::Usage;
use Getopt::Long;
use WebGUI::Session;
use List::MoreUtils qw(none insert_after_string);

# Get parameters here, including $help
GetOptions(
    'configFile=s' => \$configFile,
    'help'         => \$help,
    'man'          => \$man,
    'force'        => \$force,
    'demo'         => \$demo,
    'quiet'        => \$quiet,
);

pod2usage( verbose => 1 ) if $help;
pod2usage( verbose => 2 ) if $man;
pod2usage( msg => "Must specify a config file!" ) unless $configFile;

my $session = start( $webguiRoot, $configFile );

history_crud($session, $quiet);

print "Finished. Please restart modperl and spectre.\n";

finish($session);

sub history_crud {
    my $session = shift;
    my $quiet = shift;

    use WebGUI::History;

    if ( !$session->db->quickScalar('show tables like "history"') ) {
        print "Creating history crud... " unless $quiet;
        WebGUI::History->crud_createTable($session);
        print "DONE\n" unless $quiet;
    }
    else {
        print "Updating history crud... " unless $quiet;
        WebGUI::History->crud_updateTable($session);
        print "DONE\n" unless $quiet;
    }
}

#----------------------------------------------------------------------------
sub start {
    my $webguiRoot = shift;
    my $configFile = shift;
    my $session    = WebGUI::Session->open( $webguiRoot, $configFile );
    $session->user( { userId => 3 } );

    ## If your script is adding or changing content you need these lines, otherwise leave them commented
    #
    # my $versionTag = WebGUI::VersionTag->getWorking($session);
    # $versionTag->set({name => 'Name Your Tag'});
    #
    ##

    return $session;
}

#----------------------------------------------------------------------------
sub finish {
    my $session = shift;

    ## If your script is adding or changing content you need these lines, otherwise leave them commented
    #
    # my $versionTag = WebGUI::VersionTag->getWorking($session);
    # $versionTag->commit;
    ##

    $session->var->end;
    $session->close;
}

__END__


=head1 NAME

utility - A template for WebGUI utility scripts

=head1 SYNOPSIS

 utility --configFile config.conf ...

 utility --help

=head1 DESCRIPTION

This WebGUI utility script helps you...

=head1 ARGUMENTS

=head1 OPTIONS

=over

=item B<--configFile config.conf>

The WebGUI config file to use. Only the file name needs to be specified,
since it will be looked up inside WebGUI's configuration directory.
This parameter is required.

=item B<--help>

Shows a short summary and usage

=item B<--man>

Shows this document

=back

=head1 AUTHOR

Copyright 2001-2009 Plain Black Corporation.

=cut

#vim:ft=perl
