#! /usr/bin/perl
#use strict;
use Getopt::Long qw(Configure GetOptions);

#Funkce pro validaci xml dotazu pomoci rekurzivniho sestupu
sub validateQuery($);
sub limit($$);
sub fromElement($$);

#Pomocne funkce
sub splitQuery($);


########################################################################
#	HLAVNI CAST PROGRAMU
########################################################################
my $helpmsg = "Pouziti: ./xqr.pl
	--help - vytiskne tuto napovedu
	--input=filename - urci vstupni xml soubor
	--output=filename - urci vystupni xml soubor
	--query='dotaz' - urci dotaz provadeny nad xml daty
	--qf=filename - urci soubor, kde se nachazi xml dotaz
	-n - zajisti negenerovani xml hlavicky v cilovem dokumentu
	--root=element - jmeno paroveho korenoveho elementu ve vystupu\n";
	
my %params;	#parametry nactene ze vstupu + ze zpracovani dotazu
	
GetOptions(\%params, "--help", "--input=s", "--output=s", "--query=s", 
	"--qf=s", "-n", "--root=s") 
or die $helpmsg;

validateQuery(\%params) and die "Invalid query.\n";


########################################################################
#	DEFINICE VOLANYCH FUNKCI
########################################################################
sub validateQuery($){
	my $params = @_;
	my @words = splitQuery($params);
	my $i = 0;
	
	print @{$params{"query"}."\n";
	
	($words[$i] eq "SELECT") or return 1;		#eq pri shode vraci 1 -> or
	$i++;
	@{$params{"element"}} = $words[$i];
	$i++;
	
	if(limit($i, $params) == 0){
		@{$params{"limit"}} = $words[$i+1];	
		$i+=2;
	}

	($words[$i] eq "FROM") or return 1;
	$i++;
	
	fromElement($i, $params);
	print @{$params{"fromElement"}}. "\n";
	if(@{$params{"fromElement"}} eq ""){
		return 1;
	}
	$i++;
	
	return 0;
}

sub limit($$){
	my ($i, $params ) = @_;
	my @words = splitQuery($params);
	
	(@words[$i] eq "LIMIT")? return 0 : return 1;
}

sub fromElement($$){
	my $i = shift @_;
	my $params = @_;
	my @words = splitQuery($params);
	
	if($words[$i] eq "ROOT"){
		@{$params{"fromElement"}} = "ROOT";		# tohle
		return 0;
	}
	
	my @attrElem = split('\.', $words[$i]);
	@{$params{"fromElement"}} = $attrElem[0];		#tohle
	@{$params{"fromAttribute"}} = $attrElem[1];	#a tohle se nepreda zpatky do validateQuery...
	print $attrElem[0];
	print @{$params{"fromElement"}}."\n";
	return 0;
}

sub splitQuery($){
	my $params = @_;
	my $query = @{$params{"query"}};
	return split(' ', $query);;
}

