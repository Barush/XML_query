#! /usr/bin/perl
#use strict;
use Getopt::Long qw(Configure GetOptions);

#Funkce pro validaci xml dotazu pomoci rekurzivniho sestupu
sub validateQuery($);
sub limit($$);
sub fromElement($$);
sub whereClause($$);
sub condition($$);

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
	my $paramsPtr = shift @_;
	my @words = splitQuery($paramsPtr);
	my $i = 0;
	
	#foreach my $a (@words){
	#	print $a . "\n";}
	
	($words[$i] eq "SELECT") or return 1;		#eq pri shode vraci 1 -> or
	$i++;
	$$params{"element"} = $words[$i];
	$i++;
	
	if(limit($i, $params) == 0){
		$$params{"limit"} = $words[$i+1];	
		$i+=2;
	}

	($words[$i] eq "FROM") or return 1;
	$i++;
	
	fromElement($i, $params);
	if($$params{"fromElement"} eq ""){
		return 1;
	}
	$i++;
	
	#A TADY SI ZAVOLAME whereClause()
	
	return 0;
}

sub limit($$){
	my ($i, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	(@words[$i] eq "LIMIT")? return 0 : return 1;
}

sub fromElement($$){
	my ($i, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	if($words[$i] eq "ROOT"){
		$$params{"fromElement"} = "ROOT";		
		return 0;
	}
	
	my @attrElem = split('\.', $words[$i]);
	$$params{"fromElement"} = $attrElem[0];		
	$$params{"fromAttribute"} = $attrElem[1];	
	return 0;
}

#NOT FINISHED
sub whereClause($$){
	my ($i, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	(@words[$i] eq "WHERE") or return 1;
	$i++;
	
	condition($i, $paramsPtr);
	
	return 0;
}

#NOT FINISHED
sub condition($$){
	my ($i, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	(@words[$i] eq "(") and {$i++; condition($i, $paramsPtr)};
	(@words[$i] eq "NOT") and {$i++; condition($i, $paramsPtr)};
	
	return 0;
}

sub splitQuery($){
	my $params = shift @_;
	my $query = $$params{"query"};
	return split(' ', $query);;
}
