package modules::gim;

#use strict;
use Getopt::Std;
use Cwd;
use Time::Local;
use Term::ANSIColor;
use Sys::Hostname;
use POSIX qw(strftime);
use Capture::Tiny ':all';
use JSON::PP;
use Socket;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(read_settings extract_repo_id_from_url msg git_add_commit git_get_origin git_get_status git_add_origin git_push git_pull github_form_url ssh_check_known_host_from_git_url ssh_add_known_host get_ip_from_name);

sub read_settings {
    my $file = shift;
    open (TXT, "<".$file);
    my @lines = <TXT>;
    close TXT;
    my $json_text = join ("", @lines);
    eval {
        my $user = JSON::PP -> new -> utf8 -> decode ($json_text);
        return($user);
    } or do {
        msg( "The settings file seems to be corrupt, please check settings.json" , 0);
        exit;
    }
}

sub extract_repo_id_from_url {
    my $url = shift;
    my ($git, $repo) = split(/\//, $url);
    return($repo);
}

sub msg {
   my ($msg, $as_remote) = @_;
   $msg = $msg."\n";
   my $flag = 0;
   unless ($as_remote eq "" || $as_remote == 0) {
       print colored (['blue'], "gim (@".$as_remote."): ");
    } else {
       print colored (['green'], "gim: ");
    }
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
    my ($r, $as_remote) = @_;
    my @cmd = ("add", ".");
    my $output = $r -> run (@cmd);
    my $host = hostname;
    $host =~ s/\.local//;
    my $now = strftime "%Y%m%d_%H:%M:%S", localtime;
    my $m = $host."_".$now;
    my @cmd = ("commit", "-a", "-m '".$m."'");
    my $output = $r -> run (@cmd);
    if ($output =~ m/nothing to commit/) {
        msg("no new files or changes found locally", $as_remote);
       return(0);
     } else {
        my $n_add =()= $output =~ /create mode/gi;
        if ($n_add > 0) {
          msg("git added ".$n_add." files to repository (".$m.")", $as_remote);
        }
        return(1);
    }
}

sub git_get_origin {
    my ($r, $as_remote) = @_;
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

sub git_get_status {
    my ($r, $as_remote) = @_;
    my @cmd = ("status");
    my $output = $r -> run (@cmd);
    my @lines = split("\n", $output);
    my $out;
    my $rest;
    foreach my $line (@lines) {
        unless ($line =~ m/^#/) {
            $out .= $line . "\n";
        } else {
	    $rest .= $line;
	}
    }
    return($out, $rest);
}


sub git_add_origin {
    my ($r, $git_remote, $git_host, $repo, $flag, $as_remote) = @_;
    my $origin = git_get_origin ($r);
    if ($origin -> {origin} eq "") { # test if not already linked
        if ($repo eq "") {
            msg ("[error] no repo name specified!", $as_remote);  
            exit;          
        }
        if ($git_remote -> {$git_host} eq "") {
            msg ("[error] git server id unknown! check ~/.gim/settings.json", $as_remote);  
            exit;              
        }
        $git_remote -> {$git_host} -> {repo} = $repo;
        my $new_link = github_form_url($git_remote, $git_host); 
        my @cmd = ("remote", "add", "origin", $new_link);
        my $output = $r -> run (@cmd);
        msg("linking local repository to remote (".$repo.")", $as_remote);
    } else {
        msg("[warning] remote origin already exists!");
        unless($flag) {
            msg("removing remote link and trying again...", $as_remote);
            my @cmd = ("remote", "remove", "origin");
            my $output = $r -> run (@cmd);    
            git_add_origin($r, $git_remote, $git_host, $repo, 1, $as_remote)
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
    my ($r, $as_remote) = @_;
    my $origin = git_get_origin ($r);
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
               msg("[warning] pushing files to remote failed: ".$err, $as_remote);
               $known_err = 1;
            }           
        }
        if ($known_err == 0) {
            my $flag_done = 0;
            if ($stderr =~ m/^Everything up-to-date/) {
                msg("everything up-to-date", $as_remote);              
                $flag_done = 1;
            } 
            if ($stderr =~ m/^To /) {
                msg("changes pushed to remote", $as_remote);              
                $flag_done = 1;
            } 
            if ($flag_done == 0) {
                msg("[warning] pushing files failed: unknown error", $as_remote);
                print $stderr;
                exit;
            }
        }
    }
    #print $output;
}

sub git_pull {
    my ($r, $as_remote) = @_;
    my $origin = git_get_origin ($r);
    msg("pulling changes from central (".$origin -> {origin}.")", $as_remote);
    my $options = { "fatal" => [ -128 ] };    #    quiet => true };
    my @cmd = ("pull", "origin", "master");
    my ($stdout, $stderr, @result) = capture {
      $output = $r -> run (@cmd);
      print $stdout;
    };  
}

sub github_form_url {
    my ($gh, $host) = @_;
    my $remote = $gh -> {$host} -> {url}.":".$gh -> {$host} -> {user}."/".$gh -> {$host} -> {repo};
    return($remote);
}

sub ssh_check_known_host_from_git_url {
    my ($url, $as_remote) = @_;
    $url =~ m/\@(.*?)\:/;
    my $host = $1;
    # print("remote host: $host");

    open (IN, "<".$ENV{"HOME"}."/.ssh/known_hosts");
    my @lines = <IN>;
    my $text = join ("", @lines);
    close IN;
    if ($text =~ m/$host/i) {
        #msg("central git-repository (@".$host.") known host", $as_remote);
    } else {
        msg("unknown host (".$host."), trying to add to known host file...", $as_remote);
        ssh_add_known_host($host);
    }
}

sub ssh_add_known_host {
    my ($host, $as_remote) = @_;
    my $ip = get_ip_from_name($host);
    my @commands = (
      "ssh-keygen -R ".$host,
      "ssh-keygen -R ".$ip,
      "ssh-keygen -R ".$host.",".$ip,
      "ssh-keyscan ".$host.",".$ip." >> ~/.ssh/known_hosts",
      "ssh-keyscan ".$ip." >> ~/.ssh/known_hosts",
      "ssh-keyscan ".$host." >> ~/.ssh/known_hosts");
    msg("adding ".$host." to known hosts (if not already)");
    foreach my $cmd(@commands) {
        system $cmd;
    }
}

sub get_ip_from_name {
    my $name = shift;
    my $packed_ip = gethostbyname($name); 
    return(inet_ntoa($packed_ip));
}



1;

