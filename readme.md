# Readme #

A simple script for generating graphs for use with the LaTeX package [genealogytree](https://github.com/T-F-S/genealogytree). Requires the perl modules `Genealogy::Gedcom::Date`, `Gedcom`, and `List::MoreUtils` (available via CPAN).

Generated graphs will likely need some manual cleanup for optimal display.

Pull requests more than welcome!

```
Usage: ./mkgraph.pl -f <path to gedcom> -x <xref> [options]

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
```
