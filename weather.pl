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
my ($lat, $lon) = &getCoordinates();
my ($current, $forecast, $walkscore, $goodscore, $tzoffset) = &getData($lat, $lon);

# display weather data
if ( defined $$forecast{"alerts"} ) {
	&printAlerts( $$forecast{"alerts"} );
}
&printCurrent( $current );
&printForecast( $$forecast{"daily"} );
&printHourly( $$forecast{"hourly"} );

&printNeighbourhood( $walkscore, $goodscore );

# display credits
my $owmLink = "https://openweathermap.org/city/" . $$current{"id"};
print "<p><a href='$owmLink' target='_blank'>" . $$current{"name"} . ", " . $$current{"sys"}{"country"} . "</a> at " 
	. &getDateTime($$forecast{"current"}{"dt"}, $tzoffset) 
	. " from <a href='$owmLink' target='_blank'>OpenWeather</a>\n";
print "<br>Other Sources:\n";
if ( defined $walkscore ) {
	print "<a href='$$walkscore{'more_info_link'}' target='_blank'>Walk Score</a><sup>&reg;</sup>: <a href='$$walkscore{'ws_link'}' target='_blank'>$$walkscore{'walkscore'}</a> |\n";
}
print "<a href='https://canue-dev.herokuapp.com/map?lat=$lat&lng=$lon' target='_blank'>Goodscore</a> |\n";
print "<a href='https://www.getambee.com/' target='_blank'>Ambee</a>\n";

# add tracking image
print "<img src='https://sanvash.com/cgi-bin/log.pl'>";
&printFoot;

sub getCoordinates {
	my ($lat, $lon) = (43.7806, -79.3503);  # default location
	if ( defined param('lat') && defined param('lon') ) { 
		$lat = &untaint( param('lat') );
		$lon = &untaint( param('lon') );
	} elsif ( defined param('loc') ) {
		# got a location, so let's geocode and use it
		my $loc = &untaint( param('loc') );
		($lat, $lon) = &geocode( $loc );
	}
	&debug("Lat: $lat; Lon: $lon");
	return ($lat, $lon);
}

sub getData {
	my ($lat, $lon) = @_;
	my $apikey = &getKey("openweathermap");

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

	my $walkscore = &getWalkscore($lat, $lon);
	my $goodscore = &getGoodscore($lat, $lon);

	return ($current, $forecast, $walkscore, $goodscore, $tzoffset);
}

sub printCurrent {
	my ($w) = @_;
	my $city = "Current Conditions";
	if ( defined $$w{'name'} && $$w{'name'} ne "" ) { $city = $$w{'name'}; }	
	
	print "<h1>$city</h1>\n";
	print "<div class='tableXscroll'><table>\n";
	print "<tr>\n";
	print "<td class='current'>" . &getIcon( $$w{"weather"}[0]{"icon"}, $$w{"weather"}[0]{"description"}, "lg" ) . "</td>\n";
	print "<td class='current'>" . &round($$w{"main"}{"temp"}) . "&deg;C</td>\n";
	print "<td class='feelslike'>feels like: " . &round($$w{"main"}{"feels_like"}) . "&deg;\n";
	print "<br>humidity: " . &round($$w{"main"}{"humidity"}) . "%\n";
	print "<br>wind: " . &round($$w{"wind"}{"speed"}*3.6) . " km/h</td>\n";
	print "</tr>\n";
	print "</table></div>\n";
}

sub printForecast {
	my ($w) = @_;
	my @daily = @$w;

	# build display data
	my $arr 	= "<span class='material-icons'>arrow_right_alt</span>";
	my $up		= "<span class='material-icons'>north</span>";
	my $dn		= "<span class='material-icons'>south</span>";
	my $day 	= "";
	my $icon 	= "";
	my $periods = "";
	my $highlow = "";
	my $precip 	= "";

	for (my $i = 0; $i < 8; $i++) {
		my $f = $daily[$i];
		$day .= "<th>" . &getDate($$f{"dt"}, $tzoffset) . "</th>";
		$icon .= "<td>" . &getIcon( $$f{"weather"}[0]{"icon"}, $$f{"weather"}[0]{"description"}, "md" ) . "</td>";

		$periods .= "<td><span title='morning'>" . &round($$f{"temp"}{"morn"}) . "&deg;</span>" . 
			"$arr<span title='day'>" . &round($$f{"temp"}{"day"}) . "&deg;</span>" . 
			"$arr<span title='day'> <span title='evening'>" . &round($$f{"temp"}{"eve"}) . "&deg;</span>" . 
			"$arr<span title='day'> <span title='night'>" . &round($$f{"temp"}{"night"}) . "&deg;</span></td>\n";
		my $dayspan = &round($$f{"temp"}{"morn"}) . "&deg; &rarr; " . &round($$f{"temp"}{"day"}) . 
			"&deg; &rarr; " . &round($$f{"temp"}{"eve"}) . "&deg; &rarr; " . &round($$f{"temp"}{"night"}) . "&deg;";

		$highlow .= "<td><span title='$dayspan'>" . $up . &round($$f{"temp"}{"max"}) . "&deg; " . $dn . &round($$f{"temp"}{"min"}) . "&deg;</span></td>\n";

		$precip .= "<td>";
		if ( defined $$f{"rain"} ) {
			$precip .= "<br><span class='material-icons'>water_drop</span>" . &round($$f{"rain"}, 1) . "mm\n";
		}
		if ( defined $$f{"snow"} ) {
			$precip .= "<br><span class='material-icons'>ac_unit</span>" . &round($$f{"snow"}, 1) . "mm\n";
		}
		if ( defined $$f{"pop"} && $$f{"pop"} > 0 ) {
			$precip .= "<br>pop: " . &round($$f{"pop"} * 100) . "%\n";
		}
		$precip .= "</td>";
		$precip =~ s|<td>(<br>)+|<td>|g;
	}

	# print table
	print "<h1>Forecast</h1>\n";
	print "<div class='tableXscroll'><table>\n";
	print "<tr>$day</tr>";
	print "<tr>$icon</tr>";
	print "<tr>$highlow</tr>";
	#print "<tr>$periods</tr>";
	print "<tr>$precip</tr>";
	print "</table></div>\n";
}

sub printHourly {
	my ($w) = @_;
	my @hourly = @$w;
	
	# build display data
	my $arr 	= "<span class='material-icons'>arrow_right_alt</span>";
	my $time 	= "";
	my $icon 	= "";
	my $temp 	= "";
	my $precip 	= "";

	my ($curDate) = ("");
	for (my $i = 0; $i < 12; $i++) {
		my $f = $hourly[$i];
		
		my $timeStr = "";
		my $date = &getDate($$f{"dt"}, $tzoffset);
		if ( $curDate ne $date ) {
			$timeStr = $date . "<br>" . &getTime($$f{"dt"}, $tzoffset);
			$curDate = $date;
		} else {
			$timeStr = &getTime($$f{"dt"}, $tzoffset);
		}
		$time .= "<th>" . $timeStr . "</th>";
		$icon .= "<td>" . &getIcon( $$f{"weather"}[0]{"icon"}, $$f{"weather"}[0]{"description"}, "sm" ) . "</td>";
		$temp .= "<td>" . &round($$f{"temp"}) . "&deg;</td>";
		
		$precip .= "<td>";
		if ( defined $$f{"rain"} ) {
			$precip .= "<br><span class='material-icons'>water_drop</span>" . &round($$f{"rain"}{"1h"}, 1) . "mm\n";
		}
		if ( defined $$f{"snow"} ) {
			$precip .= "<br><span class='material-icons'>ac_unit</span>" . &round($$f{"snow"}{"1h"}, 1) . "mm\n";
		}
		if ( defined $$f{"pop"} && $$f{"pop"} > 0 ) {
			$precip .= "<br>pop: " . &round($$f{"pop"} * 100) . "%\n";
		}
		$precip .= "</td>";
		$precip =~ s|<td>(<br>)+|<td>|g;
	}

	# print table
	print "<h1>Hourly Forecast</h1>\n";
	print "<div class='tableXscroll'><table>\n";
	print "<tr>$time</tr>";
	print "<tr>$icon</tr>";
	print "<tr>$temp</tr>";
	print "<tr>$precip</tr>";
	print "</table></div>\n";
}

sub printAlerts {
	my ($w) = @_;
	
	unless ( defined $w ) { return; }  # exit when there are no alerts
	foreach (@$w) {
		# if there's no description, then set it
		unless ( defined $$_{"description"} ) { $$_{"description"} = ""; }
		
		# print the alert with the details as a tooltip
		print "<p class='alert' title='" . $$_{"description"} . "'>" . ucfirst($$_{'event'}) . " warning from " . &getDateTime($$_{"start"}, $tzoffset) . 
			" to "  . &getDateTime($$_{"end"}, $tzoffset) . " from $$_{'sender_name'}.\n";
	}
}

sub printHead {
   print header;
   print <<EOF;
	<!DOCTYPE html>
	<html lang="en">
	<head>
		<meta charset="UTF-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<title>Weather</title>
		<link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
		<link href="https://weather.sanvash.com/weather.css" rel="stylesheet" type="text/css">
	</head>
	<body><div>
	<div class="background"></div>
	<div class="topRight" id="addressForm">
		<form id="getNames" action="https://sanvash.com/cgi-bin/weather.pl">
			<input name="loc" value="" placeholder="address" onchange="submit()">
		</form>
	</div>
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
	my ($icon, $alt, $size) = @_;
	unless ( defined $size ) { $size = "lg"; }
	return '<img class="' . $size . '" src="https://openweathermap.org/img/wn/' . $icon . '@2x.png" title="' . $alt . '">';
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

sub getWalkscore {
	my ($lat, $lon) = @_;
	my $apikey = &getKey("walkscore");
	my $url = "https://api.walkscore.com/score?format=json&lat=$lat&lon=$lon&transit=1&bike=1&wsapikey=$apikey";
	my $json = &getPage( $url );
	my $res = decode_json($json);
	
	if ( $$res{"status"} == 1 ) {
		# clean up records
		if ( defined $$res{'transit'}{'summary'} ) {
			$$res{'transit'}{'summary'} =~ s|, 0 other||;
		}
		return $res;
	} else {
		# not successful
		return undef;
	}
}

sub getGoodscore {
	my ($lat, $lon) = @_;
	my $url = "https://canue-dev.herokuapp.com/api/score?lng=$lon&lat=$lat";
	my $json = &getPage( $url );
	my $res = decode_json($json);

	if ( defined $$res{"scores"} ) {
		return $$res{"scores"};
	} else {
		# not successful
		return undef;
	}
}

sub printNeighbourhood {
	my ($ws, $gs) = @_;
	unless ( defined $ws || defined $gs ) { return; }

	# we know we have a score at this point
	my $scores = "";
	my $descriptions = "";

	# if we have a Walk Score
	if ( defined $ws ) {
		if ( defined $$ws{'walkscore'} ) {
			$scores .= "<td class='score'><span class='material-icons-big'>directions_walk</span> $$ws{'walkscore'}</td>\n";
			$descriptions .= lc "<td class='description'>$$ws{'description'}</td>\n";
		}
		if ( defined $$ws{'transit'}{'score'} ) {
			$scores .= "<td class='score'><span class='material-icons-big'>directions_transit</span> $$ws{'transit'}{'score'}</td>\n";
			$descriptions .= lc "<td class='description'><span title='$$ws{'transit'}{'summary'}'>$$ws{'transit'}{'description'}</span></td>\n";
		}
		if ( defined $$ws{'bike'}{'score'} ) {
			$scores .= "<td class='score'><span class='material-icons-big'>directions_bike</span> $$ws{'bike'}{'score'}</td>\n";
			$descriptions .= lc "<td class='description'>$$ws{'bike'}{'description'}</td>\n";
		}
	}

	# if we have a Good Score
	if ( defined $gs ) {
		$scores .= "<td class='score'><span class='material-icons-big'>storefront</span> $$gs{'amenities'}</td>\n";
		$descriptions .= "<td class='description'>amenities</td>\n";
		$scores .= "<td class='score'><span class='material-icons-big'>nature</span> $$gs{'greenness'}</td>\n";
		$descriptions .= "<td class='description'>greenness</td>\n";
		$scores .= "<td class='score'><span class='material-icons-big'>nature_people</span> $$gs{'parks'}</td>\n";
		$descriptions .= "<td class='description'>parks &amp; rec</td>\n";
		$scores .= "<td class='score'><span class='material-icons-big'>commute</span> $$gs{'transportation'}</td>\n";
		$descriptions .= "<td class='description'>transit options</td>\n";
		$scores .= "<td class='score'><span class='material-icons-big'>air</span> $$gs{'air_quality'}</td>\n";
		$descriptions .= "<td class='description'>air quality</td>\n";
	}

	print "<h1>Neighbourhood Scores</h1>\n";
	print "<div class='tableXscroll'><table>\n";
	print "<tr>$scores</tr>\n";
	print "<tr>$descriptions</tr>\n";
	print "</table></div>\n";
	
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
