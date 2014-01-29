package modules::gim;

#use strict;
use Getopt::Std;
use Cwd;
use Time::Local;
use Term::ANSIColor;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(msg git_add_commit git_get_origin git_add_origin git_push github_form_url);

sub msg {
   my ($msg, $v) = @_;
   $msg = "gim: ".$msg."\n";
   my $flag = 0;
   if ($msg =~ m/\[error\]/) { print colored (['bold red'], 'bold red'); $flag = 1; };
   if ($msg =~ m/\[warning\]/) { print colored (['bold yellow'], $msg); $flag = 1 };
   if (!$flag) { print $msg; };
}

## add files and commit to the repo
sub git_add_commit {
    my $r = shift;
    my @cmd = ("add", ".");
    my $output = $r -> run (@cmd);
    my @cmd = ("commit", "-a", "-m 'test'");
    my $output = $r -> run (@cmd);
    if ($output =~ m/nothing to commit/) {
        msg("git reports 'nothing to commit'");
    } else {
        my $n_add =()= $output =~ /create mode/gi;
        if ($n_add > 0) {
          msg("git added ".$n_add." files to repository");
        }
    }
}

sub git_get_origin {
    my $r = shift;
    my @cmd = ("remote", "-v");
    my $output = $r -> run (@cmd);
#    $output =~ s/\t/\s/g;
#    $output =~ s/[\s*]/\s/g;
    my @lines = split("\n", $output);
    my $or;
    foreach my $line (@lines) {
        if ($line =~ m/\(push\)/) {
            my ($origin, $val, $rest) = split(" ", $line);
            $or -> {$origin} = $val;
        }
    }
    return($or);       
}

sub git_add_origin {
    my ($r, $git_remote, $repo, $flag) = @_;
    my $origin = git_get_origin ($r);
    if ($origin -> {origin} eq "") { # test if not already linked
        if ($repo eq "") {
            msg ("[error] no repo name specified!");  
            exit;          
        }
        $git_remote -> {repo} = $repo;
        my $new_link = github_form_url($git_remote); 
        my @cmd = ("remote", "add", "origin", $new_link);
        my $output = $r -> run (@cmd);
        msg("linking local repository to remote repository (".$repo.")");
    } else {
        msg("[warning] remote origin already exists!");
        unless($flag) {
            msg("removing remote link and trying again...");
            my @cmd = ("remote", "remove", "origin");
            my $output = $r -> run (@cmd);    
            git_add_origin($r, $git_remote, $repo, 1)
        }
        exit;
    } 
    my $origin = git_get_origin ($r);
    if ($origin -> {origin} ne "") {
        msg("successfully linked to ".$origin -> {origin});    
    } else {
        msg("something went wrong...");    
        exit;    
    }
}

sub git_push {
    my $r = shift;
    my $origin = git_get_origin ($r);
    msg("pushing files to remote repository (".$origin -> {origin}.")...");
    my @cmd = ("push", "-u", "origin", "master");
    my $output = $r -> run (@cmd);
    #print $output;
}

sub github_form_url {
    my $gh = shift;
    my $remote = $gh -> {url}.":".$gh -> {user}."/".$gh -> {repo};
    return($remote);
}


1;

