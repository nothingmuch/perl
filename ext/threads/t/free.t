use strict;
use warnings;

BEGIN {
    if ($ENV{'PERL_CORE'}){
        chdir 't';
        unshift @INC, '../lib';
    }
    use Config;
    if (! $Config{'useithreads'}) {
        print("1..0 # Skip: Perl not compiled with 'useithreads'\n");
        exit(0);
    }
}

use ExtUtils::testlib;

use threads;

BEGIN {
    eval {
        require threads::shared;
        import threads::shared;
    };
    if ($@ || ! $threads::shared::threads_shared) {
        print("1..0 # Skip: threads::shared not available\n");
        exit(0);
    }

    $| = 1;
    print("1..29\n");   ### Number of tests that will be run ###
};

my $TEST;
BEGIN {
    share($TEST);
    $TEST = 1;
}

ok(1, 'Loaded');

sub ok {
    my ($ok, $name) = @_;

    lock($TEST);
    my $id = $TEST++;

    # You have to do it this way or VMS will get confused.
    if ($ok) {
        print("ok $id - $name\n");
    } else {
        print("not ok $id - $name\n");
        printf("# Failed test at line %d\n", (caller)[2]);
    }

    return ($ok);
}


### Start of Testing ###

# Tests freeing the Perl interperter for each thread
# See http://www.nntp.perl.org/group/perl.perl5.porters/110772 for details

my ($COUNT, $STARTED) :shared;

sub threading_1 {
    my $tid = threads->tid();
    ok($tid, "Thread $tid started");

    my $id;
    {
        lock($STARTED);
        $STARTED++;
        $id = $STARTED;
    }
    if ($STARTED < 5) {
        sleep(1);
        threads->create('threading_1')->detach();
    }

    if ($id == 1) {
        sleep(2);
    } elsif ($id == 2) {
        sleep(6);
    } elsif ($id == 3) {
        sleep(3);
    } elsif ($id == 4) {
        sleep(1);
    } else {
        sleep(2);
    }

    lock($COUNT);
    $COUNT++;
    cond_signal($COUNT);
    ok($tid, "Thread $tid done");
}

{
    $STARTED = 0;
    $COUNT = 0;
    threads->create('threading_1')->detach();
    {
        my $cnt = 0;
        while ($cnt < 5) {
            {
                lock($COUNT);
                cond_wait($COUNT) if ($COUNT < 5);
                $cnt = $COUNT;
            }
            threads->create(sub {
                threads->create(sub { })->join();
            })->join();
        }
    }
    sleep(1);
}
ok($COUNT == 5, "Done - $COUNT threads");


sub threading_2 {
    my $tid = threads->tid();
    ok($tid, "Thread $tid started");

    {
        lock($STARTED);
        $STARTED++;
    }
    if ($STARTED < 5) {
        threads->create('threading_2')->detach();
    }
    threads->yield();

    lock($COUNT);
    $COUNT++;
    cond_signal($COUNT);

    ok($tid, "Thread $tid done");
}

{
    $STARTED = 0;
    $COUNT = 0;
    threads->create('threading_2')->detach();
    threads->create(sub {
        threads->create(sub { })->join();
    })->join();
    {
        lock($COUNT);
        while ($COUNT < 5) {
            cond_wait($COUNT);
        }
    }
    sleep(1);
}
ok($COUNT == 5, "Done - $COUNT threads");


{
    threads->create(sub { })->join();
}
ok(1, 'Join');


sub threading_3 {
    my $tid = threads->tid();
    ok($tid, "Thread $tid started");

    {
        threads->create(sub {
            my $tid = threads->tid();
            ok($tid, "Thread $tid started");

            sleep(1);

            lock($COUNT);
            $COUNT++;
            cond_signal($COUNT);

            ok($tid, "Thread $tid done");
        })->detach();
    }

    lock($COUNT);
    $COUNT++;
    cond_signal($COUNT);

    ok($tid, "Thread $tid done");
}

{
    $COUNT = 0;
    threads->create(sub {
        threads->create('threading_3')->detach();
        {
            lock($COUNT);
            while ($COUNT < 2) {
                cond_wait($COUNT);
            }
        }
    })->join();
    sleep(1);
}
ok($COUNT == 2, "Done - $COUNT threads");

# EOF