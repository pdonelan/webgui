package WebGUI::Macro::p_previousMenuHorizontal;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001 Plain Black Software.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use WebGUI::Macro;
use WebGUI::Privilege;
use WebGUI::Session;
use WebGUI::SQL;

#-------------------------------------------------------------------
sub _replacement {
        my ($temp, @data, $sth, $first);
        $temp = '<span class="horizontalMenu">';
        $first = 1;
        $sth = WebGUI::SQL->read("select title,urlizedTitle,pageId from page where parentId=$session{page}{parentId} order by sequenceNumber",$session{dbh});
        while (@data = $sth->array) {
        	if (WebGUI::Privilege::canViewPage($data[2])) {
                	if ($first) {
                        	$first = 0;
                        } else {
                                $temp .= " &middot; ";
                        }
                        $temp .= '<a class="horizontalMenu" href="'.$session{env}{SCRIPT_NAME}.'/'.$data[1].'">'.$data[0].'</a>';
                }
        }
        $sth->finish;
        $temp .= '</span>';
	return $temp;
}

#-------------------------------------------------------------------
sub process {
	my ($output, $temp, @data, $sth, $first);
	$output = $_[0];
        $output =~ s/\^p\;/_replacement()/ge;
        #---everything below this line will go away in a later rev.
        if ($output =~ /\^p/) {
                $temp = '<span class="horizontalMenu">';
                $first = 1;
                $sth = WebGUI::SQL->read("select title,urlizedTitle,pageId from page where parentId=$session{page}{parentId} order by sequenceNumber",$session{dbh});
                while (@data = $sth->array) {
                        if (WebGUI::Privilege::canViewPage($data[2])) {
                                if ($first) {
                                        $first = 0;
                                } else {
                                        $temp .= " &middot; ";
                                }
                                $temp .= '<a class="horizontalMenu" href="'.$session{env}{SCRIPT_NAME}.'/'.$data[1].'">'.$data[0].'</a>';
                        }
                }
                $sth->finish;
                $temp .= '</span>';
                $output =~ s/\^p/$temp/g;
        }
	return $output;
}

1;

