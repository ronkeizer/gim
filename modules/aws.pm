package modules::aws;

#use strict;
use Getopt::Std;
use Cwd;
use Time::Local;
use Term::ANSIColor;
use Sys::Hostname;
use POSIX qw(strftime);
use Capture::Tiny ':all';
use JSON::PP;
#use Net::Amazon::EC2;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(start_instance);

sub start_instance {

}

sub get_instance_list {

}

sub kill_instance {
    
}

1;

