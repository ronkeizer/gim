package modules::gim;

#use strict;
use Getopt::Std;
use Cwd;
use Time::Local;
use Term::ANSIColor;
use Sys::Hostname;
use POSIX qw(strftime);
use Capture::Tiny ':all';
use JSON::XS;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(read_settings msg git_add_commit git_get_origin git_add_origin git_push github_form_url);

sub read_settings {
    my $file = shift;
    open (TXT, "<".$file);
    my @lines = <TXT>;
    close TXT;
    my $json_text = join ("", @lines);
    my $user = JSON::XS->new->utf8->decode ($json_text);
    return($user);
}

sub msg {
   my ($msg, $v) = @_;
   $msg = $msg."\n";
   my $flag = 0;
   print colored (['green'], "gim: ");
   if ($msg =~ m/\[error\]/) { 
     $msg =~ s/\[error\]//; 
     print colored (['red'], "[error]"); 
   };
   if ($msg =~ m/\[warning\]/) { 
     $msg =~ s/\[warning\]//; 
     print colored (['yellow'], "[warning]"); 
   };
   #if (!$flag) { 
    print $msg;
   #  };
}

## add files and commit to the repo
sub git_add_commit {
    my $r = shift;
    my @cmd = ("add", ".");
    my $output = $r -> run (@cmd);
    my $host = hostname;
    $host =~ s/\.local//;
    my $now = strftime "%Y%m%d_%H:%M:%S", localtime;
    my $m = $host."_".$now;
    my @cmd = ("commit", "-a", "-m '".$m."'");
    my $output = $r -> run (@cmd);
    if ($output =~ m/nothing to commit/) {
        msg("no new files or changes found");
    } else {
        my $n_add =()= $output =~ /create mode/gi;
        if ($n_add > 0) {
          msg("git added ".$n_add." files to repository (".$m.")");
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
        msg("linking local repository to remote (".$repo.")");
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
    msg("pushing files to cloud (".$origin -> {origin}.")");
    my $options = { "fatal" => [ -128 ] };    #    quiet => true };
    my @cmd = ("push", "-u", "origin", "master", $options);
    my ($stdout, $stderr, @result) = capture {
      $output = $r -> run (@cmd);
    };  
    if ($stderr ne "") {
        my $known_err = 0;
        my @errors = ("could not resolve hostname");            
        foreach my $err (@errors) {
            if ($stderr =~ m/$err/i) {
               msg("[warning] pushing files to remote failed: ".$err);
               $known_err = 1;
            }           
        }
        if ($known_err == 0) {
            my $flag_done = 0;
            if ($stderr =~ m/^Everything up-to-date/) {
                msg("everything up-to-date");              
                $flag_done = 1;
            } 
            if ($stderr =~ m/^To /) {
                msg("updates pushed to remote");              
                $flag_done = 1;
            } 
            if ($flag_done == 0) {
                msg("[warning] pushing files failed: unknown error");
                print $stderr;
                exit;
            }
        }
    }

    #print $output;
}

sub github_form_url {
    my $gh = shift;
    my $remote = $gh -> {url}.":".$gh -> {user}."/".$gh -> {repo};
    return($remote);
}


1;
