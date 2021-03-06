#!/usr/bin/perl -w
require 5.003;	# keep this compatible, an old perl is all we may have before
                # we build the new one

# The idea is to move the regen_headers target out of the Makefile so that
# it is possible to rebuild the headers before the Makefile is available.
# (and the Makefile is unavailable until after Configure is run, and we may
# wish to make a clean source tree but with current headers without running
# anything else.

use strict;
my $perl = $^X;

# keep warnings.pl in sync with the CPAN distribution by not requiring core
# changes.  Um, what ?
# safer_unlink ("warnings.h", "lib/warnings.pm");

# We no longer need the values on this mapping, as the "changed" message is
# now generated by regen_lib.pl, so should we just drop them?

my %gen = (
	   'autodoc.pl'  => [qw[pod/perlapi.pod pod/perlintern.pod]],
	   'embed.pl'    => [qw[proto.h embed.h embedvar.h global.sym
				perlapi.h perlapi.c]],
	   'keywords.pl' => [qw[keywords.h]],
	   'opcode.pl'   => [qw[opcode.h opnames.h pp_proto.h pp.sym]],
	   'regcomp.pl'  => [qw[regnodes.h]],
	   'warnings.pl' => [qw[warnings.h lib/warnings.pm]],
	   'reentr.pl'   => [qw[reentr.c reentr.h]],
	   'overload.pl' => [qw[overload.c overload.h]],
	   );

sub do_cksum {
    my $pl = shift;
    my %cksum;
    for my $f (@{ $gen{$pl} }) {
	local *FH;
	if (open(FH, $f)) {
	    local $/;
	    $cksum{$f} = unpack("%32C*", <FH>);
	    close FH;
	} else {
	    warn "$0: $f: $!\n";
	}
    }
    return %cksum;
}

# this puts autodoc.pl last, which can be useful as it reads reentr.c
foreach my $pl (reverse sort keys %gen) {
  my @command =  ($^X, $pl, @ARGV);
  print "@command\n";
  system @command;
}
