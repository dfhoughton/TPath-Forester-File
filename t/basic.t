use v5.10;
use strict;
use warnings;

use Test::More;
use TPath::Forester::File qw(tff);
use File::Temp ();
use Cwd qw(getcwd);
use FindBin qw($Bin);
use lib "$Bin/lib";
use TreeMachine;

my $dir = getcwd;

my $td = File::Temp::tempdir();
chdir $td;

file_tree(
    {
        name     => 'a',
        children => [
            { name => 'b', binary => 1 },
            {
                name => 'c',
                text => "theße are the times\nthat try men's souls"
            },
            {
                name     => 'd',
                children => [
                    {
                        name     => 'e',
                        children => [ { name => 'h', text => '' } ]
                    },
                    { name => 'f', binary => 1 },
                    {
                        name     => 'g',
                        encoding => 'iso-8859-1',
                        text     => "one çine"
                    }
                ]
            }
        ],
    }
);

my @files;

my $a = tff->wrap('a');

tff->path('//@f[@T & @log(@name, @enc, @exec("cat _"))]')->select($a);

@files = tff->path('//@bin')->select($a);
is @files, 2, 'found right number of binary files';
is join( '', sort map { $_->name } @files ), 'bf',
  'found the correct files';

@files = tff->path('//@B')->select($a);
is @files, 6, 'found right number of -B files';
is join( '', sort map { $_->name } @files ), 'abdefh',
  'found the correct files';

@files = tff->path('//@txt')->select($a);
is @files, 3, 'found right number of text files';
is join( '', sort map { $_->name } @files ), 'cgh', 'found the correct files';

@files = tff->path('//@z')->select($a);
is @files, 1, 'found right number of empty files';
is $files[0]->name, 'h', 'found correct empty file';

@files = tff->path('/a/*')->select($a);
is @files, 3, 'found three children of a';
is join( '', map { $_->name } @files ), 'bcd', 'found the correct children';

@files = tff->path('//@f')->select($a);
is @files, 5, 'found correct number of file files';
is join( '', sort map { $_->name } @files ), 'bcfgh', 'found the correct files';

@files = tff->path('//@d')->select($a);
is @files, 3, 'found correct number of directories';
is join( '', sort map { $_->name } @files ), 'ade',
  'found the correct directories';

@files = tff->path('//*[@lines = 2]')->select($a);
is @files, 1, 'found right number of two-line files';
is $files[0]->name, 'c', 'found correct two-line file';

TODO: {
    local $TODO = 'encoding detection needs more work';

    @files = tff->path('//*[@text =|= "theße"]')->select($a);
    is @files, 1, 'found right number of files containing a ß';
    is @files && $files[0]->name, 'c', 'found correct file containing ß';

    @files = tff->path('//*[@text =|= "çine"]')->select($a);
    is @files, 1, 'found right number of files containing a ç';
    is @files && $files[0]->name, 'g', 'found correct file containing ç';
}

chdir $dir;
rmtree($td);

done_testing();
