package MyGit::Hello;

use strict;
use warnings;

use Git::Repository::Plugin;
our @ISA      = qw( Git::Repository::Plugin );
sub _keywords { qw( myhello ) }

sub myhello { return "Hello, my git world!\n" }

1;

