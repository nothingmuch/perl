#!/usr/bin/perl -w

# Test that @INC is propogated from the harness process to the test
# process.

use strict;
use lib 't/lib';

sub has_crazy_patch {
    my $sentinel = 'blirpzoffle';
    local $ENV{PERL5LIB} = $sentinel;
    my $command = join ' ',
      map {qq{"$_"}} ( $^X, '-e', 'print join q(:), @INC' );
    my $path = `$command`;
    my @got = ( $path =~ /($sentinel)/g );
    return @got > 1;
}

use Test::More (
      $^O eq 'VMS' ? ( skip_all => 'VMS' )
    : has_crazy_patch() ? ( skip_all => 'Incompatible @INC patch' )
    : ( tests => 2 )
);

use Test::Harness;

# Change @INC so we ensure it's preserved.
use lib 'wibble';

my $test_template = <<'END';
#!/usr/bin/perl %s

use Test::More tests => 2;

# Make sure we did something sensible with PERL5LIB
like $ENV{PERL5LIB}, qr{wibble};
ok grep { $_ eq 'wibble' } @INC;

END

open TEST, ">inc_check.t.tmp";
printf TEST $test_template, '';
close TEST;

open TEST, ">inc_check_taint.t.tmp";
printf TEST $test_template, '-T';
close TEST;
END { 1 while unlink 'inc_check_taint.t.tmp', 'inc_check.t.tmp'; }

for my $test ( 'inc_check_taint.t.tmp', 'inc_check.t.tmp' ) {
    my ( $tot, $failed ) = Test::Harness::execute_tests( tests => [$test] );
    is $tot->{bad}, 0;
}
1;
