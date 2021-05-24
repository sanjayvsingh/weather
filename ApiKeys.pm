package ApiKeys;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = 1.00;
@ISA = qw(Exporter);
@EXPORT = qw(getKey);
@EXPORT_OK = qw();
%EXPORT_TAGS = (
   DEFAULT => [qw(&getKey)]
);

sub getKey {
	my ($key, $loc) = @_;
	my $file = "data.key";
	
	if ( defined $loc ) {
		$file = $loc . $file;
	}
	
	open(DATA, $file) || die "Cannot open $file.\n$!\n";
	while (<DATA>) {
		if ( m|$key:(.*?)$| ) {
			return $1;
		}
	}
	close(DATA) || die "Cannot close $file.\n$!\n";
	die "Cannot find key $key.\n$!\n";
}
