#!/usr/bin/env perl

use warnings;
use diagnostics;
use strict;

use Getopt::Long qw(:config no_auto_abbrev);

use Gedcom;
use Genealogy::Gedcom::Date;
use List::MoreUtils qw(firstidx);

my $DEBUG = 0;

my $gedfile;
my $xref;
my $ancestorcount = 0;
my $descendantcount = 0;
my $includefloruit = 0;
my $marriageoption = "family";
my @ignore = [];

sub usage() {
	print <<USAGE;
Usage: $0 -f <path to gedcom> -x <xref> [options]

	-f / --file        : path to Gedcom file
	-x / --xref        : xref for an individual in the file
	-a / --ancestors   : number of ancestor generations to graph
	-d / --descendants : number of descendant generations to graph
	-m / --marriage    : where to put marriage info. one of [family, proband, spouse],
	                   : 'family' is default.
	-i / --ignore      : ignore these xrefs (individuals & families)
	--floruit          : calculate floruit information from all individual events
	--debug            : output debugging info on STDERR
	-h / --help        : display this message
	
Graph will be printed to STDOUT.

Note: Either ancestors or descendants (or both) must be specified.
USAGE
	exit;
}

GetOptions(
	"f|file=s" => \$gedfile,
	"x|xref=s" => \$xref,
	"a|ancestors:i" => \$ancestorcount,
	"d|descendants:i" => \$descendantcount,
	"m|marriage:s" => \$marriageoption,
	"i|ignore:s" => \@ignore,
	"floruit" => \$includefloruit,
	"debug" => \$DEBUG,
	"h|help" => sub { &usage() })
or &usage();

if (!defined $gedfile) { &usage(); }
if (!defined $xref) { &usage(); }
if (!grep {$_ eq $marriageoption} qw/family proband spouse/) { &usage(); }

@ignore = split(/,/,join(',',@ignore));

print STDERR "% DEBUG: Looking for $xref in $gedfile...\n" if $DEBUG;

my $parserA = Genealogy::Gedcom::Date->new();
my $parserB = Genealogy::Gedcom::Date->new();
my $ged = Gedcom->new(gedcom_file => $gedfile,
					  read_only   => 1
					 );

my $proband = $ged->get_individual($xref);

print STDERR "% DEBUG: Found ".&processName($proband)."\n" if $DEBUG;
print STDERR "% DEBUG: Ancestor generations requested: $ancestorcount\n" if $DEBUG;
print STDERR "% DEBUG: Descendant generations requested: $descendantcount\n" if $DEBUG;

my $depth = 0;

if ($ancestorcount > 0) {
	if ($descendantcount > 0) {
		print STDERR "% DEBUG: Going to make a 'sandclock' subgraph\n" if $DEBUG;
		
		&startnode($depth++, "sandclock", &familyOptions($proband->famc));
		&printAncestors($proband, $depth--, $ancestorcount);
		&startnode($depth++, "child", &familyOptions($proband->fams));
		&DEBUG($depth, "Proband", $proband);
		&printIndividual("g", $proband, $depth);
		&printDescendants($proband, $depth--, $descendantcount);
		&endnode($depth);
		&endnode($depth);
	} else {
		print STDERR "% DEBUG: Going to make a 'parent' subgraph\n" if $DEBUG;
		
		&startnode($depth++, "parent", &familyOptions($proband->famc));
		&DEBUG($depth, "Proband", $proband);
		&printIndividual("g", $proband, $depth);
		&printAncestors($proband, $depth--, $ancestorcount);
		&endnode($depth);
	}
} elsif ($descendantcount > 0) {
	print STDERR "% DEBUG: Going to make a 'child' subgraph\n" if $DEBUG;
	
	&startnode($depth++, "child", &familyOptions($proband->fams));
	&DEBUG($depth, "Proband", $proband);
	&printIndividual("g", $proband, $depth);
	&printDescendants($proband, $depth--, $descendantcount);
	&endnode($depth);
} else {
	print "You must specify either ancestors or descendants or both!\n";
	&usage();
}

exit; ####################################################################################

sub DEBUG() {
	my $indent = shift;
	my $title = shift;
	my $indi = shift;
	
	print STDERR ("\t"x$indent)."% DEBUG: $title: ".$indi->name." (".$indi->xref.")\n" if $DEBUG;
}

sub startnode() {
	my $indent = shift;
	my $nodetype = shift;
	my $options = shift;
	
	print "\t"x$indent;
	print $nodetype;
	if (defined $options) {
		print "[".$options."]";
	}
	print "{\n";
}

sub endnode() {
	my $indent = shift;
	
	print "\t"x$indent;
	print "}\n";
}

##########################################################################################

sub processMonth() {
	my $month = shift;
	
	return substr("00".((firstidx { /$month/i } qw/JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC/)+1), -2);
}

sub processDate() {
	my $date = shift;
	
	$date =~ s/^(ABT|EST|CAL) /(caAD)/;
	$date =~ s/(?:(\d\d?) )?(...) (\d\d\d\d)/"$3-".&processMonth($2).(defined $1 ? "-".substr("00$1",-2) : "")/ge;
	$date =~ s|BEF (.*)|/$1|;
	$date =~ s|AFT (.*)|$1/|;
	$date =~ s|FROM (.*) TO (.*)|$1/$2|;
	$date =~ s|BET (.*) AND (.*)|$1/$2|;
	$date =~ s|\s+\([^)]+\)||;
	
	return $date;
}

sub processPlace() {
	my $place = shift;
	
	#TODO configure?
	$place =~ s/([^,]+),.*/$1/; # remove extraneous places (assumes a hierarchy)
	
	return $place;
}

sub processEvent() {
	my $tag = shift;
	my $event = shift;
	my $indent = shift;
	my $modifierString = shift;
	
	return "" if ($event eq "0");
	return "" if ($event eq "Y");
	# Fix for https://github.com/mikkelee/genealogytree-mkgraph/issues/1
	if (ref($event) ne 'Gedcom::Record') {
		print STDERR "% DEBUG: Ignoring malformed $tag event: $event\n";
		return "";
	}
	return "" if (!defined $event->date);
	
	my $modifier = "-";
	
	if (defined $event->place) {
		$modifier = "";
	}
	if (defined $modifierString) {
		$modifier = "+";
	}
	
	return "".("\t"x$indent).$tag.$modifier." = {".&processDate($event->date)."}"
		.(defined $event->place ? "{".&processPlace($event->place)."}" : (defined $modifierString ? "{}" : ""))
		.(defined $modifierString ? "{$modifierString}" : "")
		.($indent > 0 ? ",\n" : "");
}

sub processName() {
	my $name = shift->name;
	
	$name =~ s|/([^/]+)/|\\surn{$1}|;
	$name =~ s|"([^"]+)"|\\nick{$1}|;
	
	return $name; 
}

sub isBefore() {
	my $dateA = shift;
	my $dateB = shift;
	my $resA = $parserA->parse(date => $dateA);
	my $resB = $parserB->parse(date => $dateB);
	
	return ($parserA->compare($parserB)) == 1;
}

##########################################################################################

sub printIndividual() {
	my $nodetype = shift;
	my $indi = shift;
	my $indent = shift;
	my $is_spouse = shift;
	
	&startnode($indent++, $nodetype, "id=".$indi->xref);
	if (my $sex = $indi->sex) {
		print "".("\t"x($indent)).($sex =~ m/^M(?:ale)?$/i ? "male" : "female").",\n";
	}
	if (my $name = $indi->record('name')) {
		print "".("\t"x($indent))."name = {".&processName($indi)."},\n";
	}
	if (my $birth = $indi->record('birth')) {
		my $fam = $indi->famc;
		my $modifier;
		if (defined $fam) {
			if (defined $fam->get_value("_UMR") && $fam->get_value("_UMR") eq "Y") {
				$modifier = "out of wedlock";
			} elsif (defined $fam->get_value("marriage date") && &isBefore($indi->get_value("birth date"), $fam->get_value("marriage date"))) {
				$modifier = "out of wedlock";
			}
		}
		if (my $death = $indi->record('death')) {
			if ($death->age && $death->age eq "STILLBORN" || $death->date eq $birth->date)  {
				$modifier = 'stillborn';
			}
		}
		print &processEvent("birth", $birth, $indent, $modifier);
	}
	if (my $baptism = $indi->record('baptism')) {
		print &processEvent("baptism", $baptism, $indent);
	} elsif (my $christening = $indi->record('christening')) {
		print &processEvent("baptism", $christening, $indent);
	}
	if (my $death = $indi->record('death')) {
		print &processEvent("death", $death, $indent);
	}
	if (my $burial = $indi->record('burial')) {
		print &processEvent("burial", $burial, $indent);
	}
	if (my $cremation = $indi->record('cremation')) {
		print &processEvent("cremation", $cremation, $indent);
	}
	if (my $occupation = $indi->occupation) {
		$occupation =~ s/\&/\\\&/;
		print "".("\t"x($indent))."profession = {".join(", ", $occupation)."},\n";
	}
	if (($marriageoption eq "proband" && not $is_spouse) || ($marriageoption eq "spouse" && $is_spouse)) {
		if (defined $indi->fams && (my $marr = $indi->fams->record('marriage'))) {
			print &processEvent("marriage", $marr, $indent);
		}
	}
	if ($includefloruit) {
		my $first = 9999;
		my $last = 0000;
		foreach my $event ($indi->items) {
			if (my $date = $event->date && $event->tag ne "CHAN") { # TODO include marriage events + child birth years?
				$event->date =~ m/(\d{4})/; # TODO handle ranges/periods
				my $year = $1;
				print STDERR "".("\t"x($indent))."% DEBUG: floruit ".$event->tag." year: $year\n" if $DEBUG;
				if ($year < $first) { $first = $year };
				if ($year > $last) { $last = $year };
			}
		}
		print "".("\t"x($indent))."floruit- = {$first/$last},\n";
	}
	&endnode(--$indent);
}

sub familyOptions() {
	my $family = shift;
	
	my $options;
	
	if (defined $family) {
		$options = "id=".$family->xref;
		
		if ($marriageoption eq "family") {
			my $familyOptions = &processEvent("marriage", $family->record('marriage'), 0);
			if (defined $familyOptions && $familyOptions ne "") {
				$options .= ", family database={$familyOptions}";
			}
		}
	}
	
	return $options;
}

sub recurse() {
	my $indi = shift;
	my $indent = shift;
	my $depth = shift;
	my $nodetype = shift;
	my $method = shift;
	my $options = shift;
	
	return if (grep {$_ eq $indi->xref} @ignore);
	
	if ($depth > 1) {
		&startnode($indent, $nodetype, $options);
		&printIndividual("g", $indi, $indent+1);
		$method->($indi, $indent+1, $depth-1);
		&endnode($indent);
	} else {
		&printIndividual(substr($nodetype,0,1), $indi, $indent);
	}
}

sub printAncestors() {
	my $indi = shift;
	my $indent = shift;
	my $depth = shift;
	
	my $family = $indi->famc;
	
	return if (!defined $family);
	return if (grep {$_ eq $family->xref} @ignore);
	
	my $father = $family->husband;
	if (defined $father) {
		&DEBUG($indent, "Father", $father);
		&recurse($father, $indent, $depth, "parent", \&printAncestors, &familyOptions($father->famc));
	}
	
	my $mother = $family->wife;
	if (defined $mother) {
		&DEBUG($indent, "Mother", $mother);
		&recurse($mother, $indent, $depth, "parent", \&printAncestors, &familyOptions($mother->famc));
	}
}

sub printDescendants() {
	my $indi = shift;
	my $indent = shift;
	my $depth = shift;
	
	my $is_subsequent = 0;
	
	foreach my $fam ($indi->fams) {
		next if (grep {$_ eq $fam->xref} @ignore);
		
		my $spouse = $indi->sex eq "M" ? $fam->wife : $fam->husband;
		
		&startnode($indent, "union", &familyOptions($fam)) if ($is_subsequent);
		if (defined $spouse) {
			&DEBUG($indent+$is_subsequent, "Spouse", $spouse);
			&printIndividual("p", $spouse, $indent+$is_subsequent, 1);
		}
		foreach my $child ($fam->children) {
			&DEBUG($indent+$is_subsequent, "Child", $child);
			&recurse($child, $indent+$is_subsequent, $depth, "child", \&printDescendants, &familyOptions($child->fams));
		}
		&endnode($indent) if ($is_subsequent);
		
		$is_subsequent++;
	}
}

