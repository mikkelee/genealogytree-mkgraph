# Readme #

A simple script for generating graphs to use with the LaTeX package [genealogytree](https://github.com/T-F-S/genealogytree).

Graphs will likely need cleanup.

Pull requests more than welcome!

```
Usage: ./mkgraph.pl -f <path to gedcom> -x <xref> [options]

	-f / --file        : path to Gedcom file
	-x / --xref       : xref for an individual in the file
	-a / --ancestors   : number of ancestor generations to graph
	-d / --descendants : number of descendant generations to graph
	-i / --ignore      : ignore these xrefs (individuals & families)
	--debug            : output debugging info on STDERR
	-h / --help        : display this message

Graph will be printed to STDOUT.

Note: Either ancestors or descendants (or both) must be specified.
```
