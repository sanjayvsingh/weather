package WebTools;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use LWP::UserAgent;
#use HTTP::Cookies::Mozilla;
#use Data::Dumper;

$VERSION = 1.00;
@ISA = qw(Exporter);
@EXPORT = qw(getPage untaint);
@EXPORT_OK = qw();
%EXPORT_TAGS = (
   DEFAULT => [qw(&getPage &untaint)]
);


sub getPage {
   # If one arg, then it returns the contents of that web page.
   # If two args, then it saves the contents of the url to the second arg.
   my ($url, $savefile) = @_;
   my $ua = LWP::UserAgent->new;

   $ua->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0');

   # make up a referrer string
   my $ref = "";
   if ( $url =~ m|(http://[^/]+)| ) {
      $ref = $1;
   }
   my $req = HTTP::Request->new(GET => $url);
   $req->header("Referer" => $ref);
   if ( defined $savefile ) {
      my $res = $ua->request($req, $savefile);
      return ($$res{'_rc'}, $$res{'_msg'});
   } else {
      my $res = $ua->request($req);
      return ($$res{'_rc'}, $$res{'_content'});
   }
}

sub untaint {
	my ($str) = @_;
	if ($str =~ /^([\w\s\.\-\@,]+)$/) {
		# $data now untainted
		return $1;  
	} else {
		# log this somewhere
		die "Bad data in '$str'";  
	}
}

1; # return 1

