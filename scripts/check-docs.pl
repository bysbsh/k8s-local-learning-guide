#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use File::Basename qw(dirname);
use File::Spec;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my @files = split /\n/, `git -c core.quotePath=false ls-files --cached --others --exclude-standard -- '*.md'`;
my $failed = 0;

for my $file (@files) {
    open my $handle, '<:encoding(UTF-8)', $file
        or die "Cannot read $file: $!\n";
    local $/;
    my $content = <$handle>;
    close $handle;

    my $fence_count = () = $content =~ /^```/mg;
    if ($fence_count % 2 != 0) {
        print STDERR "Unbalanced fenced code block: $file\n";
        $failed = 1;
    }

    while ($content =~ /\]\(([^)]+)\)/g) {
        my $link = $1;
        $link =~ s/^<|>$//g;

        next if $link =~ /^#/;
        next if $link =~ /^[a-z][a-z0-9+.-]*:/i;

        my ($target) = split /#/, $link, 2;
        next if !defined $target || $target eq '';

        my $path = File::Spec->canonpath(
            File::Spec->catfile(dirname($file), $target)
        );

        if (!-e $path) {
            print STDERR "Missing local link target: $file -> $target\n";
            $failed = 1;
        }
    }
}

exit $failed;
