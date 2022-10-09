#!/usr/bin/perl

# AptPkg::Cache tests

BEGIN { print "1..67\n" }

sub check_keys
{
    my ($test, $thing, $expect) = @_;
    for my $key (keys %$expect)
    {
	print $thing->{$key} eq $expect->{$key}
	    ? "ok $test\n"
	    : "not ok $test # $thing->{$key} != $expect->{$key}\n";

	$test++;
    }

    $test;
}

use AptPkg::Config '$_config';
use AptPkg::System '$_system';
use AptPkg::Cache;

$ENV{APT_CONFIG} = 't/cache/etc/apt.conf';

$_config->init;
$_system = $_config->system;

print "ok 1\n";

my $cache = AptPkg::Cache->new;

# cache created
unless ($cache)
{
    print "not ok 2\n";
    exit;
}

my $verfile; # for ->packages test

# package "b" exists
if (my $b = $cache->{b})
{
    print "ok 2\n";

    # check some string values
    check_keys 3, $b, {
	Name => 'b',
	FullName => 'b:i386',
	ShortName => 'b',
	Arch => 'i386',
	Section => 'test',
	SelectedState => 'Install',
	InstState => 'Ok',
	CurrentState => 'TriggersPending',
    };

    # expected current version
    print 'not ' unless $b->{CurrentVer}{VerStr} eq '0.2-1';
    print "ok 11\n";

    # installed and two new versions are available
    print 'not ' unless @{$b->{VersionList}} == 3;
    print "ok 12\n";

    # newest version is first
    print 'not ' unless $b->{VersionList}[0]{VerStr} eq '0.3-2';
    print "ok 13\n";

    # stash verfile from stable version
    if (my $f = $b->{VersionList}[1]{FileList})
    {
	$verfile = $f->[0];
    }
    else
    {
	print 'not ';
    }

    print "ok 14\n";

    # last is current version
    print 'not ' unless $b->{VersionList}[-1]{VerStr} eq '0.2-1';
    print "ok 15\n";

    # check rev depends
    my $r;
    if (@{$b->{RevDependsList}} == 2)
    {
	($r) = grep {
		$_->{ParentPkg}{Name} eq 'a' and
		$_->{ParentVer}{VerStr} eq '0.1'
	    } @{$b->{RevDependsList}};
    }

    if ($r)
    {
	print "ok 16\n";

	print 'not ' unless $r->{DepType} eq 'Depends';
	print "ok 17\n";

	print 'not ' unless $r->{TargetPkg}{Name} eq 'b';
	print "ok 18\n";

	print 'not ' unless $r->{CompType} eq '>=';
	print "ok 19\n";

	print 'not ' unless $r->{TargetVer} eq '0.2-3';
	print "ok 20\n";
    }
    else
    {
	print "not ok 16 # no rev depends\n";
	print "ok $_ # skip\n" for 17..20;
    }


    # check sizes from the newest version
    print 'not ' unless $b->{VersionList}[0]{Size} == 30000;
    print "ok 21\n";

    print 'not ' unless $b->{VersionList}[0]{InstalledSize} == 300 * 1024;
    print "ok 22\n";
}
else
{
    print "not ok 2 # package b missing\n";
    print "ok $_ # skip\n" for 3..22;
}

# package "a" exists
if (my $a = $cache->{a})
{
    print "ok 23\n";

    # check some string values
    check_keys 24, $a, {
	Name => 'a',
	Section => 'test',
	SelectedState => 'Unknown',
	InstState => 'Ok',
	CurrentState => 'NotInstalled',
    };

    # expect two versions to be available
    print 'not ' unless @{$a->{VersionList}} == 2;
    print "ok 29\n";

    # check version (stable version)
    print 'not ' unless $a->{VersionList}[1]{VerStr} eq '0.1';
    print "ok 30\n";

    # check provides
    print 'not ' unless @{$a->{VersionList}[1]{ProvidesList}} == 1;
    print "ok 31\n";

    my $p = $a->{VersionList}[1]{ProvidesList}[0];
    print 'not ' unless $p->{Name} eq 'quux';
    print "ok 32\n";

    print 'not ' unless $p->{OwnerPkg}{Name} eq 'a';
    print "ok 33\n";

    print 'not ' unless $p->{OwnerVer}{VerStr} eq '0.1';
    print "ok 34\n";

    # check relationships
    my $d = $a->{VersionList}[1]{DependsList} || [];

    my %rel;
    $rel{$_->{DepType}} = $_ for @$d;

    if (my $d = $rel{Depends})
    {
	print "ok 35\n";

	print 'not ' unless $d->{TargetPkg}{Name} eq 'b';
	print "ok 36\n";

	print 'not ' unless $d->{CompType} eq '>=';
	print "ok 37\n";

	print 'not ' unless $d->{TargetVer} eq '0.2-3';
	print "ok 38\n";
    }
    else
    {
	print "not ok 35 # bad depends\n";
	print "ok $_ # skip\n" for 36..38;
    }

    my $c = $rel{Conflicts};
    my $b = $rel{Breaks};
    my $e = $rel{Enhances};

    print 'not ' unless $c and $c->{TargetPkg}{Name} eq 'foo';
    print "ok 39\n";

    print 'not ' unless $b and $b->{TargetPkg}{Name} eq 'bar';
    print "ok 40\n";

    print 'not ' unless $e and $e->{TargetPkg}{Name} eq 'baz';
    print "ok 41\n";
}
else
{
    print "not ok 23 # package a missing\n";
    print "ok $_ # skip\n" for 24..41;
}

# test files
my $f = $cache->files;
my $status;
my $packages;
my $status_dir = '';

if ($f and @$f == 5)
{
    for (my $i = 0; $i < @$f; $i++)
    {
	for ($f->[$i]{FileName})
	{
	    if (/\bstatus$/)
	    {
		$status = $i;
		# status filename is absolute in newer apt-pkg versions
		($status_dir = `pwd`) =~ s#\n#/# if m#^/#;
		next;
	    }
	    /stable_.*_Packages$/ and $packages = $i;
	}
    }
}

if (defined $status and defined $packages)
{
    print "ok 42\n";

    check_keys 43, $f->[$status], {
	FileName => $status_dir . 't/cache/var/status',
	Archive => 'now',
	IndexType => 'Debian dpkg status file',
    };

    check_keys 46, $f->[$packages], {
	FileName => 't/cache/var/lists/_test_dists_stable_main_binary-i386_Packages',
	Origin => 'Debian',
	Label => 'Debian',
	Archive => 'stable',
	Version => '3.0',
	Component => 'main',
	IndexType => 'Debian Package Index',
    };
}
else
{
    print "not ok 42 # bad ->files\n";
    print "ok $_ # skip\n" for 43..52;
}

if (my $p = $cache->packages)
{
    # check by name
    if (my $a = $p->lookup('a'))
    {
	print "ok 53\n";

	check_keys 54, $a, {
	    Name => 'a',
	    Section => 'test',
	    VerStr => '0.5',
	    Maintainer => 'Brendan O\'Dea <bod@debian.org>',
	    FileName => 'pool/main/a/a/a_0.5_i386.deb',
	    MD5Hash => '0123456789abcdef0123456789abcdef',
	    ShortDesc => 'Test Package "a"',
	    LongDesc => qq/Test Package "a"\n This is a bogus package for the AptPkg::Cache test suite./,
	};
    }
    else
    {
	print "not ok 53 # lookup by name failed\n";
	print "ok $_ # skip\n" for 54..61;
    }

    # check by verfile
    if ($verfile)
    {
	if (my $b = $p->lookup($verfile))
	{
	    print "ok 62\n";

	    check_keys 63, $b, {
		Name => 'b',
		Maintainer => 'Brendan O\'Dea <bod@debian.org>',
		FileName => 'pool/main/b/b/b_0.3-1_i386.deb',
		MD5Hash => '0123456789abcdef0123456789abcdef',
		ShortDesc => 'Test Package "b"',
	    };
	}
	else
	{
	    print "not ok 62 # lookup by verfile failed\n";
	    print "ok $_ # skip\n" for 63..67;
	}
    }
    else
    {
	print "ok $_ # skip\n" for 62..67;
    }
}
else
{
    print "not ok 53 # bad ->packages\n";
    print "ok $_ # skip\n" for 54..67;
}
