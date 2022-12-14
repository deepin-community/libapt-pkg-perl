#!/usr/bin/perl

# AptPkg::Policy tests

BEGIN { print "1..8\n" }

use AptPkg::Config '$_config';
use AptPkg::System '$_system';
use AptPkg::Cache;
use AptPkg::Policy;

$ENV{APT_CONFIG} = 't/cache/etc/apt.conf';

$_config->init;
$_system = $_config->system;

print "ok 1\n";

my $cache = AptPkg::Cache->new;
my $policy = $cache->policy;

# policy created
unless ($policy)
{
    print "not ok 2\n";
    exit;
}

# package "a" exists
if (my $a = $cache->{a})
{
    print "ok 2\n";

    # expect stable candidate
    my $c = $policy->candidate($a);
    print 'not ' unless $c and $c->{VerStr} eq '0.1';
    print "ok 3\n";

    # get archive priorities
    my %prio;
    for my $v (@{$a->{VersionList}})
    {
	for my $f (map $_->{File}, @{$v->{FileList}})
	{
	    $prio{$1} = $policy->priority($f)
		if $f->{FileName} =~ /_dists_([^_]+)_main_/;
	}
    }

    # default prio
    print 'not ' unless $prio{stable} eq '500';
    print "ok 4\n";

    # pinned
    print 'not ' unless $prio{testing} eq '50';
    print "ok 5\n";
}
else
{
    print "not ok 2 # package a missing\n";
    print "ok $_ # skip\n" for 3..5;
}

if (my $b = $cache->{b})
{
    print "ok 6\n";

    # expect pinned candidate
    my $c = $policy->candidate($b);
    print 'not ' unless $c and $c->{VerStr} eq '0.2-1';
    print "ok 7\n";

    my $p = $policy->priority($c);
    print 'not ' unless $p == 1001;
    print "ok 8\n";
}
else
{
    print "not ok 6 # package b missing\n";
    print "ok $_ # skip\n" for 7..8;
}
