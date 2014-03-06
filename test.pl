use Git::Repository;

our $r = Git::Repository -> new( 
    work_tree => ".", { 
            env => {
                GIT_COMMITTER_EMAIL => 'ronkeizer@gmail.com',
                GIT_COMMITTER_NAME  => 'Ron Keizer',
            },
        } );

print join (" ", keys(%{$r -> {work_tree}}));