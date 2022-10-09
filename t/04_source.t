#!/usr/bin/perl

# AptPkg::Source tests

BEGIN { print "1..15\n" }

use AptPkg::Config '$_config';
use AptPkg::Source;

$ENV{APT_CONFIG} = 't/cache/etc/apt.conf';

$_config->init;
$_config->{quiet} = 0;

print "ok 1\n";

my $src = AptPkg::Source->new;

# cache created
unless ($src)
{
    print "not ok 2\n";
    print "ok $_ # skip\n" for 3..15;
    exit;
}

sub check
{
    my ($test, $t) = @_;
    print 'not ' unless $t;
    print "ok $test\n";
}

# package "a" exists
my $a = $src->{a};
if ($a and @$a)
{
    print "ok 2\n";

    check 3, @$a == 1;

    $a = $a->[0];
    check 4, $a->{Package} eq 'a';
    check 5, $a->{Section} eq 'test';
    check 6, $a->{Version} eq '0.1';
    check 7, $a->{AsStr} =~ /^Package:\s+a$/m && $a->{AsStr} =~ /^Binary:\s+a$/m;
    if ($a->{Binaries} and ref $a->{Binaries} eq 'ARRAY')
    {
	check 8, "@{$a->{Binaries}}" eq 'a';
    }
    else
    {
	print "not ok 8 # no binaries\n";
    }

    if ($a->{BuildDepends} and ref $a->{BuildDepends} eq 'HASH'
	and my $b = $a->{BuildDepends}{'Build-Depends'})
    {
	check  9, $b->[0][0] eq 'b';
	check 10, $b->[0][1] == AptPkg::Dep::GreaterEq;
	check 11, $b->[0][2] eq '0.2-42';
    }
    else
    {
	print "not ok 9 # build depends\n";
	print "ok $_ # skip\n" for 10..11;
    }

    if ($a->{Files} and ref $a->{Files} eq 'ARRAY')
    {
	if (my ($dsc) = grep $_->{Type} eq 'dsc', @{$a->{Files}})
	{
	    check 12, $dsc->{ArchiveURI} =~ m!pool/main/a/a/a_0\.1\.dsc$!;
	    check 13, $dsc->{MD5Hash} eq '8202ae7d918948c192bdc0f183ab26ca';
	}
	else
	{
	    print "not ok 12 # no dsc\n";
	    print "ok 13 # skip\n";
	}

	if (my ($tgz) = grep $_->{Type} eq 'tar', @{$a->{Files}})
	{
	    check 14, $tgz->{ArchiveURI} =~ m!pool/main/a/a/a_0\.1\.tar\.gz$!;
	    check 15, $tgz->{MD5Hash} eq 'a54a02be45314a8eea38058b9bbea7da';
	}
	else
	{
	    print "not ok 14 # no tar\n";
	    print "ok 15 # skip\n";
	}
    }
}
else
{
    print "not ok 2 # source a missing\n";
    print "ok $_ # skip\n" for 3..15;
}
