#! /usr/bin/perl
#use strict;
use Getopt::Long qw(Configure GetOptions);

#Funkce pro validaci xml dotazu pomoci rekurzivniho sestupu
sub validateQuery($);
sub limit($$);
sub fromElement($$);
sub whereClause($$);
sub condition($$);
sub relation($$);

#Pomocne funkce
sub splitQuery($);


########################################################################
#	HLAVNI CAST PROGRAMU
########################################################################
my $helpmsg = "Pouziti: ./xqr.pl
	--help              -vytiskne tuto napovedu
	--input=filename    -urci vstupni xml soubor
	--output=filename   -urci vystupni xml soubor
	--query='dotaz'     -urci dotaz provadeny nad xml daty
	--qf=filename       -urci soubor, kde se nachazi xml dotaz
	-n                  -zajisti negenerovani xml hlavicky v cilovem dokumentu
	--root=element      -jmeno paroveho korenoveho elementu ve vystupu\n";
	
my %params;	#parametry nactene ze vstupu + ze zpracovani dotazu
	
GetOptions(\%params, "--help", "--input=s", "--output=s", "--query=s", 
	"--qf=s", "-n", "--root=s") 
or die $helpmsg;

if($params{"help"}){
	(scalar keys %params > 1) and exit 1;
	print $helpmsg; 
	exit 0;
}

($params{"qf"} and $params{"query"}) and exit 1;

#($params{"qf"}) and {
#	open QUERYFILE, $params{"qf"};			#tady se deje nejaky zlo...
#};

validateQuery(\%params) and die "Invalid query.\n";


########################################################################
#	FUNKCE REKURZIVNIHO SESTUPU BKG
########################################################################
sub validateQuery($){
	my $paramsPtr = shift @_;
	my @words = splitQuery($paramsPtr);
	my $i = 0;
	my $i_ptr = \$i;
	
	#foreach my $a (@words){
	#	print $a . "\n";}
	
	($words[$i] eq "SELECT") or return 1;		#eq pri shode vraci 1 -> or
	$i++;
	$$params{"element"} = $words[$i];
	$i++;

	(limit($i_ptr, $paramsPtr) == 0);

	($words[$i] eq "FROM") or return 1;
	$i++;
		
	fromElement($i_ptr, $paramsPtr);
	if($$paramsPtr{"fromElement"} eq ""){
		return 1;
	}
	$i++;
	
	whereClause($i_ptr, $paramsPtr) and return 1;
	
	return 0;
}

sub limit($$){
	my ($i_ptr, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	if(@words[$$i_ptr] eq "LIMIT"){
		$$i_ptr++;
		$$paramsPtr{"limit"} = $words[$$i_ptr];
		$$i_ptr++;
		return 0;
	}
	return 0;
}

sub fromElement($$){
	my ($i_ptr, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	if($words[$$i_ptr] eq "ROOT"){
		$$paramsPtr{"fromElement"} = "ROOT";		
		return 0;
	}
	
	my @attrElem = split('\.', $words[$$i_ptr]);
	$$paramsPtr{"fromElement"} = $attrElem[0];		
	$$paramsPtr{"fromAttribute"} = $attrElem[1];	
	return 0;
}

sub whereClause($$){
	my ($i_ptr, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	(@words[$$i_ptr] eq "WHERE") or return 0;
	$$i_ptr++;
	
	condition($i_ptr, $paramsPtr) and return 1;
	return 0;
}

sub condition($$){
	my ($i_ptr, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	if(@words[$$i_ptr] eq "("){
		$$i_ptr++; 
		condition($i_ptr, $paramsPtr); 
		return 0;
	}
		
	if(@words[$$i_ptr] eq "NOT"){
		$$i_ptr++; 
		condition($i_ptr, $paramsPtr);
		return 0;
	}
	
	my @attrElem = split('\.', $words[$$i_ptr]);
	$$paramsPtr{"whereElement"} = $attrElem[0];		
	$$paramsPtr{"whereAttribute"} = $attrElem[1];
	$$i_ptr++;
	relation($i_ptr, $paramsPtr) and return 1;
	$$paramsPtr{"literal"} = $words[$$i_ptr];
	$$i_ptr++;
	
	return 0;
}

sub relation($$){
	my ($i_ptr, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	$$paramsPtr{"cmp"}	= $words[$$i_ptr];
	$$i_ptr++;	
	if(($$paramsPtr{"cmp"} ne "=") and ($$paramsPtr{"cmp"} ne ">") and ($$paramsPtr{"cmp"} ne "<")){
		return 1;
	}
	return 0;
}

########################################################################
#	POMOCNE FUNKCE
########################################################################
sub splitQuery($){
	my $params = shift @_;
	my $query = $$params{"query"};
	return split(' ', $query);;
}
