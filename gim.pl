################################################################################################
### Initialize
################################################################################################
use strict;
use Cwd qw(fastgetcwd realpath);
use File::Basename;
use Git::Repository;
use Term::ANSIColor;

#*** include modules in INC
BEGIN{
   my $base_dir = &File::Basename::dirname(realpath($0));
   push (@INC, $base_dir);
}
use modules::gim qw(msg git_add_commit git_get_origin git_add_origin git_push github_form_url);

my @all_args = @ARGV;
my $key = @all_args[0];
print "\n*** Gim version 0.1 \n";
print "*** Jan 2014, by Ron Keizer \n\n";
my $git_remote = {
 "user" => "ronkeizer",
 "url" => 'git@github.com'
};

################################################################################################
## Interpret what to do from command line
################################################################################################

if (@all_args == 0) {
    msg("No arguments to gim.");
    exit;
}
my @gim_cmds = qw/init clone sync status link/;
my @psn_cmds = qw/execute bootstrap vpc/;
my @all_cmd;
#push (@all_cmd, @gim_cmd, @psn_cmd);
my $psn_cmd; my $gim_cmd; my $local = 0; my $loc_id;
if ( $key ~~ @gim_cmds ) { # do a gim command?
    $gim_cmd = $key;
    $local = 1;
#   msg("running gim command ".$key);
} 
if ( $key ~~ @psn_cmds ) { # do a psn command locally ?
    $psn_cmd = $key;
#    msg("running PsN command '".$psn_cmd."' on local machine.");
    $local = 1;
} 
if ($key eq "local") {
    $local = 1;
}
unless ($local) {
    $loc_id = shift(@all_args); 
}

################################################################################################
## Initialize Git repo, save changes if necessary, push to remote
################################################################################################

our $cwd = ".";
my $dir = $cwd;
unless (-d $dir."/.git") {
    msg ("creating new git repository in current folder.");
    Git::Repository -> run( 
        init => $dir,
        { 
            env => {
                GIT_COMMITTER_EMAIL => 'ronkeizer@gmail.com',
                GIT_COMMITTER_NAME  => 'Ron Keizer',
            },
        } );
}
our $r = Git::Repository -> new( 
    work_tree => $dir, { 
            env => {
                GIT_COMMITTER_EMAIL => 'ronkeizer@gmail.com',
                GIT_COMMITTER_NAME  => 'Ron Keizer',
            },
        } );
if ($r =~ m/HASH/) {
    msg("loaded git repository in current folder.");
}
# print join(" ",keys(%$r))."\n";
# print "* gim: Options: ".join(" ",keys(%{$r -> {options}}));

################################################################################################
## Run gim command if specified
################################################################################################

if ($gim_cmd ne "") {
    shift(@all_args);
    if ($gim_cmd eq "sync") {
        msg("Looking for unsaved changes in current folder...");
        git_add_commit ($r);
    }
    if ($gim_cmd eq "link") {
        my $repo = shift(@all_args);
        $repo =~ s/\s\r\n//g;
        unless($repo eq "") {
            git_add_origin($r, $git_remote, $repo);
        } else {
            msg("no repo name specified.");
            exit;
        }
    }
    msg("done.");
    exit;
}

# origin: git@github.com:ronkeizer/test.git

################################################################################################
## Run the PsN command, either locally or remote
################################################################################################

if ($gim_cmd eq "") {
    
    ## add files to the repo if new results available
    my $origin = git_get_origin ($r);
    if ($origin -> {origin} eq "") {
        msg("no remote repository specified yet for this project. Please use 'gim link [repo]'");
        exit;
    }
    git_add_commit($r);
    git_push($r);

    my $psn_cmd = join (" ", @all_args);
    if ($local) {
        msg("running on local machine: ".$psn_cmd."\n");
        system ($psn_cmd);
    } 

    if (!$local) {
        msg("running on ".$loc_id.": ".$psn_cmd);
    }
}
msg("\ndone.");
exit;
