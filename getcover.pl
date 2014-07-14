#!/usr/bin/perl -- # -*- Perl -*-

use strict;
use warnings;
use Net::Amazon;
use Getopt::Long;
use Config::Tiny;
use LWP::UserAgent;
use Data::Dumper;
use FindBin;

Getopt::Long::Configure ("bundling","auto_help","auto_version");
$main::VERSION=0.5;
my $usage = "Usage: $0 -a artist -k keywords -f filename\n";
my @locations = ($ENV{HOME},$FindBin::Bin);
my $file = '.getcoverrc';
my $configfile;
my $c;

## Find config file
foreach my $i (@locations) {
     $configfile = $i.'/'.$file;
     $c = Config::Tiny->read($configfile);
     last if (not Config::Tiny->errstr);
}

## Defaults for opts/Config file.
my $o = {  #query
           mode => 'music', 
           #options
           filename =>  "/tmp/cover.jpg", 
           require => 0,
           verbose => 0,
           #amazon
           locale => 'uk', 
           type => 'Medium',
           max_pages => 1,
           secret_key => undef,
           associate_tag =>'getcover-21',
           token => undef,
           Format => "Audio CD",
         };

my @q = ( 'artist', 'keyword', 'keywords', 'title', 'mode', 'sort',  'type', 'Format', 'all'  );
my @a = ( 'secret_key', 'max_pages', 'locale', 'token', 'associate_tag' ); 

## Args
die $usage if !GetOptions($o , #query
                            'artist|a=s',
                            'keywords|k=s', 
                            'title|t=s',
			    'mode|m=s',
			    'sort=s',
			    'Format=s',
			    'keyword=s',
			    'all=s',
                               #options
                            'require|r',
                            'config|c=s',
                            'verbose|v+',
                            'filename|f=s',
                            'strip|s',
                            'guess|g',
                               #amazon
                            'secret_key|secret=s',
                            'max_pages=i',
                            'locale=s',
                            'token=s');
                        
$c = Config::Tiny->read($o->{config}) or (warn "$o->{config} failed ",Config::Tiny->errstr,".\n" and $file=$o->{config}) if (exists($o->{config}));
die $usage."config file not found locations(@locations) for $file" if ($o->{require} && !$c);

## Write config and die?

#my $hash ={};
#@{$hash}{@a} = @{$o}{@a};
#print Dumper(@{ { } } {@a} = @{$o}{@a});

## Merege Config file
#
@{$o}{keys $c->{_}} = values $c->{_} if ($c);

## Striping of keywords
#
$o->{'keywords'} = sanitise($o->{'keywords'}) if (exists($o->{'keywords'}) && exists($o->{'strip'}));
$o->{'title'} = sanitise($o->{'title'}) if (exists($o->{'title'}) && exists($o->{'strip'}));

## Checks
#
print Data::Dumper->Dump([$o],["*opts"]) if ${$o}{verbose} >= 3;
print Data::Dumper->Dump([$c],["*conf"]) if ${$o}{verbose} >= 3;

## Processing
#
my $lwpua = LWP::UserAgent->new() or die "LWP UserAgent failed";
$lwpua->env_proxy;

my $amzua = Net::Amazon->new(map { exists $o->{$_} ? ($_ => $o->{$_}) : () } @a) or die "Amazon object failed";
print Data::Dumper->Dump( [$amzua],["*amzua"]) if ${$o}{verbose} >=3;

my $i = 1;
my %query = map { $_ => $o->{$_} } grep { exists $o->{$_} } @q;
my $r = asearch($amzua,$lwpua,%query);
warn "$r" if ($r && ${$o}{verbose});

## Guess work...
#
if ($r && $o->{'guess'}) {
   ## Try Artist in Title
   if ($r && $o->{'title'} && $o->{'artist'}) {
       my %m = %query;
       $m{'title'} = $m{'artist'}." ".$m{'title'};
       delete $m{'artist'};
       sleep 1;
       print "Trying Title search with \'$m{'title'}\'\n" if ($r && ${$o}{verbose});
       $r = asearch($amzua,$lwpua,%m);
       $i++;
       warn "$r" if ($r && ${$o}{verbose});
   } 

   ## Try Artist = Various
   if ($r && $o->{'title'} && $o->{'artist'} && not $o->{'artist'} =~ /Various/) {
       my %m = %query;
       $m{'artist'} = 'Various';
       sleep 1;
       print "Trying All search with Artist set to \'$m{'artist'}\'\n" if ($r && ${$o}{verbose});
       $r = asearch($amzua,$lwpua,%m);
       $i++;
       warn "$r" if ($r && ${$o}{verbose});
   } 

   ## Switch to all rather than title.
   if ($r && $o->{'guess'} && $o->{'title'} && $o->{'artist'}) {
       my %m = %query;
       $m{'title'} = $m{'artist'}." ".$m{'title'};
       $m{'all'} = $m{'title'};
       delete $m{'title'};
       delete $m{'artist'};
       sleep 1;
       print "Trying All search with \'$m{'all'}\'\n" if ($r && ${$o}{verbose});
       $r = asearch($amzua,$lwpua,%m);
       $i++;
       warn "$r" if ($r && ${$o}{verbose});
   }
}
die "Giving up $i Attempt",$i > 1 ? "s" : ""," made, last error $r" if $r;

## search
#

sub asearch {
   my ($amzua,$lwpua,%query) = @_;
   print Data::Dumper->Dump([ \%query ],["*query"]) if ${$o}{verbose} >=2;

   # Get a request object
   return "request failed" if (not my $response = $amzua->search(%query));
   print "Request type", ref($response),".\n" if ${$o}{verbose};

   if ($response->is_success()) {
      my $prop = $response->properties();
      print Data::Dumper->Dump([$prop],["*prop"]) if ${$o}{verbose} >=4;
  
      if (defined $prop && exists $prop->{'ImageUrlLarge'}) {
         print "Match: ", $prop->{'album'} if ${$o}{verbose};
         print " by ", join(", ", @{$prop->{'artists'}}), "\n" if $$o{verbose};

	 $response = $lwpua->get($prop->{'ImageUrlLarge'}) or return "ImageUrlLarge get Issues";
         if ($response->is_success() and $o->{filename}) {
            print $o->{filename},"\n" if ${$o}{verbose};
	    open (F,">",$o->{'filename'});
	    print F $response->content();
	    close (F);
            return undef;
         } elsif ($o->{filename}) {
           return "Error: Retiving Image $response->status_line";
         }
      } else {
         return "No ImageUrlLarge property";
      }
   } else {
      return "Error: ".$response->message();
   }
   return "Catch All, This should not happen."
}

sub sanitise {
   my ($string) = @_;
   my $v = $string;
   $string =~ s/\s?-?\s?\[[^\]]*\]//g;
   $string =~ s/\s?-?\s?\(?\s?CD\s?[1-9]\s?\)?//gi;
   $string =~ s/\s?-?\s?\(?\s?Disc\s?[1-9]\s?\)?//gi;
   $string =~ s/^[1-3][0-9][0-9][0-9]\s?-?\s?//gi;
   print "sanitise ($v) = \'$string\'\n" if ${$o}{verbose} >=2;
   return $string;
}

__END__

=head1 NAME

getcover - cover art from amazon, options and AWS account requred.

=head1 SYNOPSIS

getcover <options>

 Options:
   -c|--config=s   specifed config file location.
   -a|--artist=s   Album Artist inc Various Artists
   -t|--title=s    Search string eg album title
   -k|--keywords=s Search string eg album title
   -s|--sanitise   strip out some strings to aid searching
   -f|--filename=s Output file
   -g|--guess      Make some other querys based on the data provided
   -r|--require    abort on config file and failed search for .getcoverrc
   -v|--verbose+   Verbose up to -vvvv
   --help...

   Best in your .getcoverrc
   --secret_key=s  Amazon Secret Key
   --token=s       Amazon Token enabled for product search API.

.getcoverrc in script dir and home dir.
token=...
secret_key=...
...

EXAMPLE

  getcover -gvvs -a "Cream" -t "Anthems 2007 CD1"

  with token and secret_key in .getcoverrc for AWS access.
=cut
