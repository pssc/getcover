#!/usr/bin/perl -- # -*- Perl -*-

use strict;
use warnings;
use Net::Amazon;
use Getopt::Long;
use Config::Tiny;
use LWP::UserAgent;
use Data::Dumper;
use FindBin;

$main::VERSION=0.1;

my $usage = "Usage: $0 -a artist -k keywords -f filename\n";

my @locations = ($ENV{HOME},$FindBin::Bin);
my $file = '.getcoverrc';

my $configfile;
my $c;

foreach my $i (@locations) {
     $configfile = $i.'/'.$file;
     $c = Config::Tiny->read($configfile);
     last if (not Config::Tiny->errstr);
}

## FIME Merege...

## Defaults 
my $o = {  #query
           mode => 'music', 
           #options
           filename =>  "/tmp/cover.jpg", 
           config => 0,
           verbose => 0,
           #amazon
           locale => 'uk', 
           max_pages => 1,
           secret_key => undef,
           associate_tag =>'getcover-21',
           token => undef 
         };

my @q = ( 'artist', 'keywords', 'title','mode');
my @a = ( 'secret_key', 'max_pages', 'locale', 'token', 'associate_tag' ); 

## Args
Getopt::Long::Configure ("bundling","auto_help","auto_version");
die $usage if !GetOptions($o , #query
                            'artist|a=s',
                            'keywords|k=s', 
                            'title|t=s',
			    'mode|m=s',
                               #options
                            'config',
                            'configfile=s',
                            'verbose|v+',
                            'filename|f=s',
                               #amazon
                            'secret_key|secret=s',
                            'max_pages=i',
                            'locale=s',
                            'token=s');
                        
die $usage."config file not found locations(@locations) for $file" if ($o->{config} && !$c);

## Write config and die?


#print Dumper(map { exists $$o{$_} ? ($_ => $$o{$_}) : () } @a);
#print Dumper(map { $_ => $o->{$_} } grep { exists $o->{$_} } @a);
#my $hash ={};
#@{$hash}{@a} = @{$o}{@a};
#print Dumper(@{ { } } {@a} = @{$o}{@a});

## Merege Config file
@{$o}{keys $c->{_}} = values $c->{_} if ($c);

## Check
die $usage if (! exists($o->{'artist'}) && ! exists($o->{'keyword'}));

print Data::Dumper->Dump([$o],["*opts"]) if ${$o}{verbose};
print Data::Dumper->Dump([$c],["*conf"]) if ${$o}{verbose} >= 2;



## Processing
my $lwpua = LWP::UserAgent->new();
$lwpua->env_proxy;

my $amzua = Net::Amazon->new(map { exists $o->{$_} ? ($_ => $o->{$_}) : () } @a) or die "Amazon object failed";


# Get a request object
my $response = $amzua->search(map { $_ => $o->{$_} } grep { exists $o->{$_} } @q) or die "search request failed";

if ($response->is_success()) {
    my $prop = $response->properties();
    print Data::Dumper->Dump([$prop],["*prop"]) if ${$o}{verbose} >=3;
    if (defined $prop && exists $prop->{'ImageUrlLarge'}) {
	print "Match: ", $prop->{'album'};
	print " by ", join(", ", @{$prop->{'artists'}}), "\n";

	$response = $lwpua->get($prop->{'ImageUrlLarge'});

	if ($response->is_success()) {
            print $o->{filename},"\n" if ${$o}{verbose};
	    open (F,">",$o->{'filename'});
	    print F $response->content();
	    close (F);
	}
    } else {
	die "No ImageUrlLarge property\n";
    }
} else {
    die "Error: ", $response->message(), "\n";
}

__END__

=head1 NAME

getcover - cover art from amazon

=head1 SYNOPSIS

getcover [options]

 Options:
   --config

=cut
