package WebGUI::Asset::Wobject::IndexedSearch;

use strict;
use Time::HiRes;
use WebGUI::Asset::Wobject::IndexedSearch::Search;
use WebGUI::HTMLForm;
use WebGUI::HTML;
use WebGUI::Macro;
use WebGUI::International;
use WebGUI::Session;
use WebGUI::SQL;
use Tie::IxHash;
use WebGUI::Utility;
use WebGUI::Paginator;
use WebGUI::Asset::Wobject;

our @ISA = qw(WebGUI::Asset::Wobject);


#-------------------------------------------------------------------
sub definition {
	my $class = shift;
	my $definition = shift;
	push (@{$definition}, {
		tableName=>'IndexedSearch',
		className=>'WebGUI::Asset::Wobject::IndexedSearch',
		properties=>{
			templateId=>{
				fieldType=>"template",
				defaultValue=>"PBtmpl0000000000000034"
				},
                        indexName=>{
				fieldType=>'text',
                                defaultValue=>'default'
                                },
                        searchRoot=>{
                                fieldType=>'checkList',
                                defaultValue=>'any'
                                },
			forceSearchRoots=>{
				fieldType=>'yesNo',
				defaultValue=>1
				},
                        users=>{
                                fieldType=>'selectList',
                                defaultValue=>'any'
                                },
                        namespaces=>{
                                fieldType=>'selectList',
                                defaultValue=>'any'
                                },
                        contentTypes=>{
                                fieldType=>'selectList',
                                defaultValue=>'any'
                                },
                        paginateAfter=>{
                                defaultValue=>10
                                },
                        highlight=>{
                                defaultValue=>1
                                },
                        previewLength=>{
                                defaultValue=>130
                                },
			highlight_1=>{
				defaultValue=>'#ffff66'
				},
			highlight_2=>{
				defaultValue=>'#A0FFFF'
				},
			highlight_3=>{
				defaultValue=>'#99ff99'
				},
			highlight_4=>{
				defaultValue=>'#ff9999'
				},
			highlight_5=>{
				defaultValue=>'#ff66ff'
				},
           	      }
		});
	return $class->SUPER::definition($definition);
}

#-------------------------------------------------------------------
sub getUiLevel {
	return 5;
}

#-------------------------------------------------------------------
sub getEditForm {
	my $self = shift;
	my (@data, %indexName);
	my $tabform = $self->SUPER::getEditForm();
	tie my %searchRoot, 'Tie::IxHash';

	# Unconditional read to catch intallation errors.
	my $sth = WebGUI::SQL->unconditionalRead("select distinct(indexName), indexName from IndexedSearch_docInfo");
	unless ($sth->errorCode < 1) { 
		return "<p><b>" . WebGUI::International::get(1,"IndexedSearch") . $sth->errorMessage."</b></p>";
	}
	while (@data = $sth->array) {
		$indexName{$data[0]} = $data[1];
	}
	$sth->finish;
	unless(%indexName) {
		return "<p><b>" . WebGUI::International::get(2,"IndexedSearch") .
			 "<p>" . WebGUI::International::get(3,"IndexedSearch") . "</b></p>";
	}
	
	# Index to use
#	$tabform->getTab("properties")->radioList(	-name=>'indexName',
#					-options=>\%indexName,
#					-label=>WebGUI::International::get(5,"IndexedSearch"),
#					-value=>$self->getValue("indexName"),
#					-vertical=>1
#				);
	# NOTE: For now we're limiting each site to one index. Will allow more in the future.
	
	$tabform->getTab("properties")->hidden(
		-name=>"indexName",
		-value=>"IndexedSearch_default"
		);

	# Page roots
	#%searchRoot = (	'any'=>WebGUI::International::get(15,"IndexedSearch"), 
	#			$session{page}{pageId}=>WebGUI::International::get(4,"IndexedSearch"),
	#			WebGUI::SQL->buildHash("select pageId,title from page where parentId='0' and isSystem<>1 order by title")
	#		);
	#$tabform->getTab("properties")->checkList (	-name=>'searchRoot',
	#					-options=>\%searchRoot, 
	#					-label=>WebGUI::International::get(6,"IndexedSearch"),
	#					-value=>[ split("\n", $self->getValue("searchRoot")) ],
	#					-multiple=>1,
	#					-vertical=>1,
	#			);
	$tabform->getTab("properties")->yesNo(
					-name=>'forceSearchRoots',
						-label=>WebGUI::International::get('edit-forceSearchRoots-label',"IndexedSearch"),
						-value=>$self->getValue("forceSearchRoots")
				);
	# Content of specific user
	$tabform->getTab("properties")->selectList (	-name=>'users',
						-options=>$self->_getUsers(),
						-label=>WebGUI::International::get(7,"IndexedSearch"),
						-value=>[ split("\n", $self->getValue("users")) ],
						-multiple=>1,
						-size=>5
				);

	# Content in specific namespaces
	$tabform->getTab("properties")->selectList (	-name=>'namespaces',
						-options=>$self->_getNamespaces,
						-label=>WebGUI::International::get(8,"IndexedSearch"),
						-value=>[ split("\n", $self->getValue("namespaces")) ],
						-multiple=>1,
						-size=>5
				);

	# Only specific content types
	my $contentTypes = $self->_getContentTypes();
	delete $contentTypes->{content};
	$tabform->getTab("properties")->checkList (	-name=>'contentTypes',
						-options=>$contentTypes,
						-label=>WebGUI::International::get(10,"IndexedSearch"),
						-value=>[ split("\n", $self->getValue("contentTypes")) ],
						-multiple=>1,
						-vertical=>1,
				);
	$tabform->getTab("display")->template(
					-value=>$self->getValue("templateId"),
					-namespace=>"IndexedSearch"
		);
	$tabform->getTab("display")->integer (	-name=>'paginateAfter',
					-label=>WebGUI::International::get(11,"IndexedSearch"),
					-value=>$self->getValue("paginateAfter"),
				);
	$tabform->getTab("display")->integer        (       -name=>'previewLength',
                                        -label=>WebGUI::International::get(12,"IndexedSearch"),
                                        -value=>$self->getValue("previewLength"),
                                );
	$tabform->getTab("display")->yesNo	(	-name=>'highlight',
					-label=>WebGUI::International::get(13,"IndexedSearch"),
					-value=>$self->getValue("highlight"),
				);

	# Color picker for highlight colors
	$tabform->getTab("display")->raw 	(	-value=>'
				<SCRIPT LANGUAGE="Javascript" SRC="'.$session{config}{extrasURL}.'/wobject/IndexedSearch/ColorPicker2.js"></SCRIPT>
				<SCRIPT LANGUAGE="JavaScript">
				var cp = new ColorPicker("window");
				</SCRIPT>'
			);
	for (1..5) {
		my $highlight = "highlight_$_";
		$tabform->getTab("display")->text	(	-name=>$highlight,
					-label=>WebGUI::International::get(14,"IndexedSearch") ." $_:",
					-size=>7,
					-value=>$self->getValue($highlight),
					-subtext=>qq{
						<A HREF="#" onClick="cp.select($highlight,'$highlight');
						return false;" NAME="$highlight" ID="$highlight">Pick</A>}
				);
	}
	return $tabform;
}

#-------------------------------------------------------------------
sub getIcon {
        my $self = shift;
        my $small = shift;
        return $session{config}{extrasURL}.'/assets/small/search.gif' if ($small);
        return $session{config}{extrasURL}.'/assets/search.gif';
}

#-------------------------------------------------------------------
sub getName {
        return WebGUI::International::get(17,"IndexedSearch");
}

#-------------------------------------------------------------------
sub view {
	my $self = shift;
	my (%var, @resultsLoop);

	# Do some query handling
	$var{exactPhrase} = $session{form}{exactPhrase};
	$var{allWords} = $session{form}{allWords};
	$var{atLeastOne} = $session{form}{atLeastOne};
	$var{without} = $session{form}{without};
	$var{query} = $session{form}{query};
	$var{query} .= qq/ +"$var{exactPhrase}"/ if ($var{exactPhrase});
	$var{query} .= " ".join(" ",map("+".$_,split(/\s+/,$var{allWords}))) if ($var{allWords});
	$var{query} .= qq{ $var{atLeastOne}} if ($var{atLeastOne});
	$var{query} .= " ".join(" ",map("-".$_,split(/\s+/,$var{without}))) if ($var{without});
	
	# Remove macro's from query
	$var{query} = WebGUI::Macro::negate($var{query});
 
	# Set some standard vars
	$var{submit} = WebGUI::Form::submit({value=>WebGUI::International::get(16, "IndexedSearch")});
	$var{actionURL} = $self->getUrl;
	$var{"int.search"} = WebGUI::International::get(16,"IndexedSearch");
	$var{numberOfResults} = '0';
	$var{"select_".$self->getValue("paginateAfter")} = "selected";

	# Do the search
	my $startTime = Time::HiRes::time();
	my $filter = $self->_buildFilter;
	my $search = WebGUI::Asset::Wobject::IndexedSearch::Search->new($self->getValue('indexName'));
	$search->open;
	my $results = $search->search($var{query},$filter);
	$var{duration} = Time::HiRes::time() - $startTime;
	$var{duration} = sprintf("%.3f", $var{duration}); # Duration rounded to 3 decimal places
	# Let's see if the search returned any results
	if (defined ($results)) {
		$var{numberOfResults} = scalar(@$results);

		# Deal with pagination
		my $url = "query=".WebGUI::URL::escape($var{query});
		map {$url .= "&users=".WebGUI::URL::escape($_)} $session{cgi}->param('users');
		map {$url .= "&namespaces=".WebGUI::URL::escape($_)} $session{cgi}->param('namespaces');
		map {$url .= "&contentTypes=".WebGUI::URL::escape($_)} $session{cgi}->param('contentTypes');
		$url .= "&paginateAfter=".$self->getValue("paginateAfter");
		my $p = WebGUI::Paginator->new(WebGUI::URL::page($url), $self->getValue("paginateAfter"));
		$p->setDataByArrayRef($results);
		$var{startNr} = 1;
		if($session{form}{pn}) {
			$var{startNr} = (($session{form}{pn} - 1) * $self->getValue("paginateAfter")) + 1;
		}

		my @highlightColors = map { $self->getValue("highlight_$_") } (1..5);
		$var{queryHighlighted} = $search->highlight($var{query}, undef, \@highlightColors);

 		# Get result details for this page
		if($p->getPageNumber > $p->getNumberOfPages) {
			$var{numberOfResults} = 0; 
			$var{resultsLoop} = [];
		} else {
			$var{resultsLoop} = $search->getDetails($p->getPageData, 
									highlightColors => \@highlightColors,
									previewLength => $self->getValue('previewLength'),
									highlight => $self->getValue('highlight')
								);
			# Pagination variables
			$var{endNr} = $var{startNr}+(scalar(@{$var{resultsLoop}}))-1;
			$p->appendTemplateVars(\%var);
		}
	}

	# Create a loop with namespaces
	$var{namespaces} = [];
	my $namespaces = $self->_getNamespaces('restricted');
	foreach(keys %$namespaces) {
		my $selected = 0;
		if (scalar $session{cgi}->param('namespaces')) {
			$selected = isIn($_, $session{cgi}->param('namespaces'));
		} else {
			$selected = ($session{form}{namespaces} =~ /$_/);
		}
		push(@{$var{namespaces}}, { value => $_, name => $namespaces->{$_}, selected => $selected });
	} 

	# Create a loop with contentTypes
	#
	# And while we are busy we also create a loop with simplified contentTypes
	# This means: wobject, page, wobjectDetail are masked in one option: content

	$var{contentTypes} = [];
	$var{contentTypesSimple} = [];
	my $contentTypes = $self->_getContentTypes('restricted');
	foreach(keys %$contentTypes) {
		my $selected = 0;
		if (scalar $session{cgi}->param('contentTypes')) {
			$selected = isIn($_, $session{cgi}->param('contentTypes'));
		} else {
			$selected = ($session{form}{contentTypes} =~ /$_/);
		}
		unless(/^content$/) {	# No shortcut in the detailed contentType list
			push(@{$var{contentTypes}}, { value => $_, 
								name => $contentTypes->{$_}, 
								selected => $selected,
								'type_'.$_ => 1 });
		}
		unless(/^page|wobject|wobjectDetail$/) {	# No details in the simple contentType list
			push(@{$var{contentTypesSimple}}, { value => $_, 
									name => $contentTypes->{$_}, 
									selected => $selected,
									'type_'.$_ => 1 });
		}
	}

	# Create a loop with users
	$var{users} = [];
	my $users = $self->_getUsers('restricted');
	foreach(keys %$users) {
		my $selected = 0;
		if (scalar $session{cgi}->param('users')) {
			$selected = isIn($_, $session{cgi}->param('users'));
		} else {
			$selected = ($session{form}{users} =~ /$_/);
		}
		push(@{$var{users}}, { value => $_, name => $users->{$_}, selected => $selected });
	}

	# Create a loop with searchable page roots
	my $rootData;
	my @roots = split(/\n/, $self->get('searchRoot'));
	my %checked = map {$_=>1} $session{cgi}->param("searchRoot");
	#if (isIn('any', @roots)) {
	#	foreach $rootData (WebGUI::Page->getAnonymousRoot->daughters) {
	#		push (@{$var{searchRoots}}, {
	#			value           => $rootData->{'pageId'},
	#			menuTitle       => $rootData->{'menuTitle'},
	#			title           => $rootData->{'title'},
	#			urlizedTitle    => $rootData->{'urlizedTitle'},
	#			checked		=> $checked{$rootData->{'pageId'}},
	#		});
	#		$var{"rootPage.".$rootData->{'urlizedTitle'}.".id"} = $rootData->{'pageId'};
	#		$var{"rootPage.".$rootData->{'urlizedTitle'}.".checked"} = $checked{$rootData->{'pageId'}};
	#	}
	#} else {
	#	foreach (@roots) {
	#		$rootData = WebGUI::Page->new($_);
	#		push (@{$var{searchRoots}}, {
	#			value 		=> $rootData->get('pageId'),
	#			menuTitle 	=> $rootData->get('menuTitle'),
	#			title		=> $rootData->get('title'),
	#			urlizedTitle	=> $rootData->get('urlizedTitle'),
	#			checked         => $checked{$rootData->get('pageId')},
	#		});
	#		$var{"rootPage.".$rootData->get('urlizedTitle').".id"} = $rootData->get('pageId');
	#		$var{"rootPage.".$rootData->get('urlizedTitle').".checked"} = $checked{$rootData->get('pageId')};
	#	}
	#}
	$var{"anyRootPage.checked"} = $checked{'any'};
	# close the search
	$search->close; 
	return $self->processTemplate(\%var, $self->get("templateId"));
}

#-------------------------------------------------------------------
sub www_edit {
        my $self = shift;
        return WebGUI::Privilege::insufficient() unless $self->canEdit;
        $self->getAdminConsole->setHelp("search add/edit");
        return $self->getAdminConsole->render($self->getEditForm->print,WebGUI::International::get("26","IndexedSearch"));
}

#-------------------------------------------------------------------
sub www_view {
	my $self = shift;
	return $self->SUPER::www_view(1);
}


#-------------------------------------------------------------------
sub _buildPageList {
	my ($self, @userSpecifiedRoots, @roots, @allowedRoots, $pageId, @pages);
	$self = shift;

	@userSpecifiedRoots = $session{cgi}->param("searchRoot");
	
	if ((scalar(@userSpecifiedRoots) == 0)
		|| ($self->getValue("forceSearchRoots"))
		|| (isIn('any', @userSpecifiedRoots))
	) {
		@roots = split(/\n+/i, $self->get("searchRoot"));
	} else { 
		@allowedRoots = split(/\n+/, $self->get("searchRoot"));
		
		foreach (@userSpecifiedRoots) {
			push (@roots, $_) if (isIn($_, @allowedRoots));
		}
	}
	#foreach $pageId (@roots) {
	#	WebGUI::Page->new($pageId)->traversePreOrder(
	#		sub {
	#			push(@pages, $_[0]->get('pageId'));
	#		}
	#	);	
	#}

	return [ @pages ];
}

#-------------------------------------------------------------------
sub _buildFilter {
	my $self = shift;
	my %filter = ();
	
#	# pages
#	if($self->get('searchRoot') !~ /any/i) {
#		$filter{assetId} = $self->_buildPageList;
#	}

	# content-types
	if($session{form}{contentTypes} && ! isIn('any', $session{cgi}->param('contentTypes'))) {
		$filter{contentType} = [ $session{cgi}->param('contentTypes') ];

		# contentType "content" is a shortcut for "page", "wobject" and "wobjectDetail"
		if (isIn('content', $session{cgi}->param('contentTypes'))) {
			push(@{$filter{contentType}}, qw/Asset assetDetail/);
		}
	} elsif ($self->getValue('contentTypes') !~ /any/i) {
		$filter{contentType} = [ split(/\n/, $self->getValue('contentTypes')) ];
	}

	# users
	if($session{form}{users} && ! isIn('any', $session{cgi}->param('users'))) {
		$filter{ownerId} = [];
		foreach my $user ($session{cgi}->param('users')) {
			if ($user =~ /\D/) {
				$user =~ s/\*/%/g;
				($user) = WebGUI::SQL->buildArray("select userId from users where username like ".quote($user));
			}
			push(@{$filter{ownerId}}, quote($user)) if ($user =~ /^\d+$/);
		}
	} elsif ($self->getValue('users') !~ /any/i) {
		$filter{ownerId} = [ split(/\n/, $self->getValue('users')) ];
	}

	# namespaces
	if($session{form}{namespaces} && ! isIn('any', $session{cgi}->param('namespaces'))) {
		$filter{namespace} = [ $session{cgi}->param('namespaces') ];
	} elsif ($self->getValue('namespaces') !~ /any/i) {
		$filter{namespace} = [ split(/\n/, $self->getValue('namespaces')) ];
	}

	# delete $filter{ownerId} if it is an empty array reference
	if(exists($filter{ownerId})) {
		delete $filter{ownerId} unless (scalar(@{$filter{ownerId}}));
	}
	return \%filter;
}

#-------------------------------------------------------------------
sub _getNamespaces {
	my ($self, $restricted) = @_;
	my %international;
	foreach my $class (@{$session{config}{assets}}) {
		my $load = 'use '.$class;
		eval($load);
                if ($@) {
                        WebGUI::ErrorHandler::warn("Couldn't compile ".$class." because ".$@);
                } else {
			$international{$class} = eval{$class->getName()};
                }
        }
	tie my %namespaces, 'Tie::IxHash';
	if ($restricted and $self->get('namespaces') !~ /any/i) {
		$namespaces{any} = WebGUI::International::get(18,"IndexedSearch");
		foreach (split/\n/, $self->get('namespaces')) {
			$namespaces{$_} = $international{$_} || ucfirst($_);
		}
	} else {
		$namespaces{any} = WebGUI::International::get(18,"IndexedSearch");
		foreach (WebGUI::SQL->buildArray("select distinct(namespace) from IndexedSearch_docInfo order by namespace")) {
			$namespaces{$_} = $international{$_} ||ucfirst($_);
		}
	}
	return \%namespaces;
}

#-------------------------------------------------------------------
sub _getContentTypes {
	my ($self, $restricted) = @_;
	my %international = (	'page' => WebGUI::International::get('page',"IndexedSearch"),
					'wobject' => WebGUI::International::get(19,"IndexedSearch"),
					'wobjectDetail' => WebGUI::International::get(20,"IndexedSearch"),
					'content' => WebGUI::International::get(21,"IndexedSearch"),
					'discussion' => WebGUI::International::get('discussion',"IndexedSearch"),
					'profile' => WebGUI::International::get(22,"IndexedSearch"),
					'any' => WebGUI::International::get(23,"IndexedSearch"),
				);
	tie my %contentTypes, 'Tie::IxHash';
	if ($restricted and $self->get('contentTypes') !~ /any/i) {
		$contentTypes{any} = $international{any};
		$contentTypes{content} = $international{content};	# shortcut for page, wobject and wobjectDetail
		foreach (split/\n/, $self->get('contentTypes')) {
			$contentTypes{$_} = $international{$_};
		}
	} else {
		%contentTypes = (	'any' =>  $international{any},
					'content' => $international{content},	# shortcut for page, wobject and wobjectDetail
				);
		foreach (WebGUI::SQL->buildArray("select distinct(contentType) from IndexedSearch_docInfo order by contentType")) {
			$contentTypes{$_} = $international{$_} || ucfirst($_);
		}
	}
	return \%contentTypes;
}

#-------------------------------------------------------------------
sub _getSearchablePages {
	my $searchRoot = shift;
	my %pages;
	my $sth = WebGUI::SQL->read("select assetId from asset where parentId = ".quote($searchRoot));
	while (my %data = $sth->hash) {
		$pages{$data{assetId}} = 1;
		%pages = (%pages, _getSearchablePages($data{assetId}) );
	}
	return %pages;
}
	
#-------------------------------------------------------------------
sub _getUsers {
	my ($self, $restricted) = @_;
	tie my %users, 'Tie::IxHash';
	if ($restricted and $self->get('users') !~ /any/i) {
		$users{any} = WebGUI::International::get(25,"IndexedSearch");
		foreach (split/\n/, $self->get('users')) {
			$users{$_} = $_;
		}
	} else {
		%users = (	'any' =>  WebGUI::International::get(25,"IndexedSearch"),
				WebGUI::SQL->buildHash("select userId, username from users order by username")
			);
	}
	return \%users;
}

1;
