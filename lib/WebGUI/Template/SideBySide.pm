package WebGUI::Template::SideBySide;

our $namespace = "SideBySide";

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
use WebGUI::International;


#-------------------------------------------------------------------
sub generate {
	my ($output, $content);
	$content = $_[0];
	$output = '<table cellpadding="3" cellspacing="0" border="0" width="100%">';
	$output .= '<tr><td valign="top" class="content" width="50%">';
	$output .= ${$content}{A};
	$output .= '</td><td valign="top" class="content" width="50%">';
	$output .= ${$content}{B};
	$output .= '</td></tr></table>';
	return $output;
}

#-------------------------------------------------------------------
sub name {
        return WebGUI::International::get(362);
}

#-------------------------------------------------------------------
sub getPositions {
        return WebGUI::Template::calculatePositions('B');
}

1;

