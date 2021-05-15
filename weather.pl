#!/usr/bin/perl -w
use strict;
use WebTools;
use ApiKeys;
use JSON::XS;
use HTTP::Date;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard);
use Data::Dumper;

&printHead;

# get weather data
my ($current, $forecast, $tzoffset) = &getData();

# display weather data
if ( defined $$forecast{"alerts"} ) {
	&printAlerts( $$forecast{"alerts"} );
}
&printCurrent( $current );
&printForecast( $$forecast{"daily"} );
&printHourly( $$forecast{"hourly"} );
my $owmLink = "https://openweathermap.org/city/" . $$current{"id"};
print "<p><a href='$owmLink' target='_blank'>" . $$current{"name"} . ", " . $$current{"sys"}{"country"} . "</a> at " . &getDateTime($$forecast{"current"}{"dt"}, $tzoffset) . "\n";

# add tracking image
print "<img src='https://sanvash.com/cgi-bin/log.pl'>";
&printFoot;


sub getData {
	my $apikey = &getKey("openweathermap");

	my ($lat, $lon) = (43.7806, -79.3503);  # default location - home
	if ( defined param('lat') && defined param('lon') ) { 
		$lat = &untaint( param('lat') );
		$lon = &untaint( param('lon') );
	} elsif ( defined param('loc') ) {
		# got a location, so let's geocode and use it
		my $loc = &untaint( param('loc') );
		($lat, $lon) = &geocode( $loc );
	}
	&debug("Lat: $lat; Lon: $lon");

	# get current weather data
	my $url = "https://api.openweathermap.org/data/2.5/weather?units=metric&lat=$lat&lon=$lon&appid=$apikey";
	my $resp = &getPage( $url );
	my $current = decode_json($resp);
	&debug($url);

	# get forecast data
	$url = "https://api.openweathermap.org/data/2.5/onecall?units=metric&exclude=minutely&lat=$lat&lon=$lon&appid=$apikey";
	$resp = &getPage( $url );
	my $forecast = decode_json($resp);
	&debug($url);

	unless ( defined $current && defined $forecast ) {
		print "<p>No weather data.\n";
		print "<!--" . Debug($resp) . "-->\n";
	}

	my $tzoffset = $$forecast{"timezone_offset"};

	return ($current, $forecast, $tzoffset);
}

sub printCurrent {
	my ($w) = @_;
	my $city = "Current Conditions";
	if ( defined $$w{'name'} && $$w{'name'} ne "" ) { $city = $$w{'name'}; }	
	
	print "<h1>$city</h1>\n";
	print "<div class='tableXscroll'><table>\n";
	print "<tr>\n";
	print "<td>" . &getIcon( $$w{"weather"}[0]{"icon"}, $$w{"weather"}[0]{"description"} ) . "</td>\n";
	print "<td class='current'>" . &round($$w{"main"}{"temp"}) . "&deg;C</td>\n";
	print "<td class='feelslike'>feels like<br>" . &round($$w{"main"}{"feels_like"}) . "&deg;</td>\n";
	print "<td class='feelslike'>humidity<br>" . &round($$w{"main"}{"humidity"}) . "%</td>\n";
	print "<td class='feelslike'>wind<br>" . &round($$w{"wind"}{"speed"}*3.6) . "km/h</td>\n";
	print "</tr>\n";
	print "</table></div>\n";
}

sub printForecast {
	my ($w) = @_;
	my @daily = @$w;
	print "<h1>Forecast</h1>\n";
	print "<div class='tableXscroll'><table>\n";
	print "<tr>\n";

	my ($morn, $day, $eve, $night) = (
		" <span class='material-icons'>coffee_maker</span>",
		" <span class='material-icons'>light_mode</span>",
		" <span class='material-icons'>weekend</span>",
		" <span class='material-icons'>dark_mode</span>"
	);
	for (my $i = 0; $i < 8; $i++) {
		my $f = $daily[$i];
		print "<td>\n";
		print "<b>" . &getDate($$f{"dt"}, $tzoffset) . "</b>\n";
		print "<br>" . &getIcon( $$f{"weather"}[0]{"icon"}, $$f{"weather"}[0]{"description"} ) . "\n";

		print "<br><span title='morning'>" . &round($$f{"temp"}{"morn"}) . "&deg;</span>" . 
			" &middot; <span title='day'>" . &round($$f{"temp"}{"day"}) . "&deg;</span>" . 
			" &middot; <span title='evening'>" . &round($$f{"temp"}{"eve"}) . "&deg;</span>" . 
			" &middot; <span title='night'>" . &round($$f{"temp"}{"night"}) . "&deg;</span>";

		if ( defined $$f{"rain"} ) {
			print "<br><span class='material-icons'>water_drop</span>" . &round($$f{"rain"}, 1) . "mm\n";
		}
		if ( defined $$f{"snow"} ) {
			print "<br><span class='material-icons'>ac_unit</span>" . &round($$f{"snow"}, 1) . "mm\n";
		}
		if ( defined $$f{"pop"} && $$f{"pop"} > 0 ) {
			print "<br>pop: " . &round($$f{"pop"} * 100) . "%\n";
		}

		print "</td>\n";
		
		($morn, $day, $eve, $night) = ("", "", "", "");
	}

	print "</tr>\n";
	print "</table></div>\n";
}

sub printHourly {
	my ($w) = @_;
	my @hourly = @$w;
	print "<h1>Hourly Forecast</h1>\n";
	print "<div class='tableXscroll'><table>\n";
	print "<tr>\n";

	my ($curDate) = ("");
	for (my $i = 0; $i < 12; $i++) {
		my $f = $hourly[$i];
		print "<td>\n";
		
		my $timeStr = "";
		my $date = &getDate($$f{"dt"}, $tzoffset);
		if ( $curDate ne $date ) {
			$timeStr = $date . " " . &getTime($$f{"dt"}, $tzoffset);
			$curDate = $date;
		} else {
			$timeStr = &getTime($$f{"dt"}, $tzoffset);
		}
		print "<b>" . $timeStr . "</b>\n";
		print "<br>" . &getIcon( $$f{"weather"}[0]{"icon"}, $$f{"weather"}[0]{"description"} ) . "\n";
		print "<br>" . &round($$f{"temp"}) . "&deg;\n";
		if ( defined $$f{"rain"} ) {
			print "<br><span class='material-icons'>water_drop</span>" . &round($$f{"rain"}{"1h"}*10)/10 . "mm\n";
		}
		if ( defined $$f{"snow"} ) {
			print "<br><span class='material-icons'>ac_unit</span>" . &round($$f{"snow"}{"1h"}*10)/10 . "mm\n";
		}
		if ( defined $$f{"pop"} && $$f{"pop"} > 0 ) {
			print "<br>pop: " . &round($$f{"pop"} * 100) . "%\n";
		}
		print "</td>\n";
	}

	print "</tr>\n";
	print "</table></div>\n";
}

sub printAlerts {
	my ($w) = @_;
	
	unless ( defined $w ) { return; }  # exit when there are no alerts
	foreach (@$w) {
		print "<p class='alert'>" . ucfirst($$_{'event'}) . " warning from " . &getDateTime($$_{"start"}, $tzoffset) . 
			" to "  . &getDateTime($$_{"end"}, $tzoffset) . " from $$_{'sender_name'}.</p>\n";
	}
}

sub printHead {
   print header;
   print <<EOF;
	<html>
	<head>
		<meta http-equiv="content-type" content="text/html; charset=windows-1252">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<title>Weather</title>
		<link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
		<link href="https://weather.sanvash.com/weather.css" rel="stylesheet" type="text/css">
	</head>
	<body><div>
	<div class="background"></div>	

EOF
}

sub printFoot {
	print <<EOF;
	<br>Photo by <a href="https://unsplash.com/\@duo1ze?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText" target="_blank">Duo1ze</a> 
	on <a href="https://unsplash.com/wallpapers/nature/sky?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText" target="_blank">Unsplash</a>
	</div></body></html>
EOF
}

sub getIcon {
	my ($icon, $alt) = @_;
	return '<img src="https://openweathermap.org/img/wn/' . $icon . '@2x.png" title="' . $alt . '">';
}

sub getDateTime {
	my ($datetime, $tzoffset) = @_;
	return &getDate($datetime, $tzoffset) . " " . &getTime($datetime, $tzoffset)	
}

sub getDate {
	my ($datetime, $tzoffset) = @_;
	unless ( defined $tzoffset ) { $tzoffset = 0; }
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime ( $datetime + $tzoffset );
	my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @days = qw(Sun Mon Tue Wed Thu Fri Sat);
	my $str = "$days[$wday] $months[$mon] $mday";
	&debug("time: $datetime, offset: $tzoffset -> $str");
	return $str;
}

sub getTime {
	my ($datetime, $tzoffset) = @_;
	unless ( defined $tzoffset ) { $tzoffset = 0; }
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime ( $datetime + $tzoffset );
	my $pd = "a";

	if ( $hour == 0 ) {
		$hour = 12; # default period is "a", so we're still good
	} elsif ( $hour == 12 ) {
		$pd = "p"; # afternoon
	} elsif ( $hour > 12 ) {
		$pd = "p"; # afternoon
		$hour = $hour - 12;
	}

	if ( $min < 10 ) { $min = "0$min"; }
	my $str = "$hour:$min$pd";
	if ( $min eq "00" ) {
		# special handler for when minutes are 0 and therefore unnecessary
		if ( $hour == 12 && $pd eq "a" ) {
			$str = "midn.";
		} elsif ( $hour == 12 && $pd eq "p" ) {
			$str = "noon";
		} else {
			$str = "$hour$pd";
		}
	}
	&debug("time: $datetime, offset: $tzoffset -> $str");
	return $str;
}

sub geocode {
	my ($loc) = @_;
	my $geocodekey = &getKey("mapquest");
	my $url = "http://open.mapquestapi.com/geocoding/v1/address?key=$geocodekey&maxResults=1&location=$loc";
	my $resp = &getPage( $url );
	my $current = decode_json( $resp );
	if ( defined $$current{"info"}{"statuscode"} && $$current{"info"}{"statuscode"} == 0 ) {
		# found a match, return best match
		my $location = $$current{"results"}[0]{"locations"}[0];
		return ( $$location{"latLng"}{"lat"}, $$location{"latLng"}{"lng"} );
	} else {
		# no match, return default
		return ( 0, 0 );
	}
}

sub round {
	my ($n, $p) = @_;
	if ( defined $p && $p == 1 ) {
		# round to one decimal
		return sprintf("%.1f", $n);
	} else {
		# round to the nearest integer
		return sprintf("%.0f", $n);
	}
}

sub debug {
	my ($c) = @_;
	if ( defined param('debug') ) {
		print "<span class='debug'>[$c]</span>";
	}
}

__DATA__
Sample calls:

Current: https://api.openweathermap.org/data/2.5/weather?lat=43.7806&lon=-79.3503&appid=db1782e369a2197e7302114c6c4e70da&units=metric
Full: https://api.openweathermap.org/data/2.5/onecall?lat=43.7806&lon=-79.3503&appid=db1782e369a2197e7302114c6c4e70da&units=metric&exclude=minutely