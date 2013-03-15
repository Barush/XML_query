#! /usr/bin/perl

########################################################################
#	XQR.pl
#	autor: Barbora Skrivankova, xskriv01@stud.fit.vutbr.cz
#	datum: 15.3.2012
#	popis: projekt do IPP
#		provadi jednoduche select-like dotazy nad xml daty
########################################################################
use Getopt::Long qw(Configure GetOptions);
use XML::LibXML;
use Data::Dumper;
use strict;
use warnings;

#Funkce pro validaci xml dotazu pomoci rekurzivniho sestupu
sub validateQuery($);
sub limit($$);
sub fromElement($$);
sub whereClause($$);
sub condition($$);
sub relation($$);

#Pomocne funkce
sub splitQuery($);
sub readXML($);
sub findAttrs($$$);

#Funkce pro zpracovavani vlastniho filtrovani dat
sub elementSel($$$@);
sub evalRel($$);


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
	
my %params;		#parametry nactene ze vstupu + ze zpracovani dotazu
my $xmlFile;    #struktura z knihovny libXML uchovavajici data nactena z xml souboru
	
#nacteni parametru prikazove radky
if(!GetOptions(\%params, "--help", "--input=s", "--output=s", "--query=s", 
	"--qf=s", "-n", "--root=s") ){
	print STDERR "Interni chyba pri zpracovani parametru.\n";
	exit 1;
}

#overeni kolize neslucitelnych parametru
if($params{"help"}){
	print $helpmsg; 
	(scalar keys %params > 1) and exit 1;
	exit 0;
}
if($params{"qf"} and $params{"query"}){
	print STDERR "Chybna kombinace parametru.\n";
	print STDERR $helpmsg;
	exit 1;
}

#nacteni dotazu v pripade, ze byl uveden v souboru
if($params{"qf"}){
	if(!open(QUERYF, $params{"qf"})){
		print STDERR "Doslo k chybe pri otevirani query file.\n";
		exit 2;
	}
	chomp($params{"query"} = <QUERYF>);
	close QUERYF;
}

#volani overeni validity dotazu dle bkg ze zadani
if(validateQuery(\%params)){
	print STDERR "Dotaz nebyl zadan v podporovanem formatu. \n";
	exit 10;
}

#nacteni xml ze souboru
$xmlFile = readXML(\%params);

#vytvoreni xml dokumentu a pripadne smazani jeho hlavicky dle parametru -n
my $document = XML::LibXML->createDocument( "1.0", "utf-8" );
if($params{"n"}){
	$document = "";
}
else{
	$document = $document->toString();
}

#vlozeni obalujiciho elementu do dokumentu
if($params{"root"}){
	$document .= "<".$params{"root"}.">";
}

#citac poctu zapsanych elementu
my $counter = 1;

#volani funkci pro zpracovani dotazu
if($params{"fromElement"} eq "ROOT"){
	if($params{"fromAttribute"}){	
		#nalezeni uzlu, ktere obsahuji hledany atribut	
		my @matchingNodes;
		findAttrs(\%params, $xmlFile, \@matchingNodes);
		elementSel(\%params, \$document, \$counter, @matchingNodes);
	}
	else {
		elementSel(\%params, \$document, \$counter, $xmlFile->childNodes());
	}
}
else{
	#nalezeni vsech elementu - pouzije se bud prvni nalezeny nebo ten s odpovidajicim
	#atributem
	my @allElements = $xmlFile->getElementsByTagName($params{"fromElement"});
	if($params{"fromAttribute"}){
		my $elem;
		foreach $elem (@allElements){
			my @attrs = $elem->attributes();
			my $attr;
			foreach $attr (@attrs){
				if($attr->toString() =~ /$params{"fromAttribute"}.*/){
					#prvni element natvrdo prepisem...
					$allElements[0] = $elem;
					last;
				}
			}
		}
	}
	elementSel(\%params, \$document, \$counter, $allElements[0]);
}

#vlozeni ukoncujiciho korenoveho elementu do dokumentu
if($params{"root"}){
	$document .= "</".$params{"root"}.">";
}

#zapis do souboru
if($params{"output"}){
	if(!open(OUTF, ">", $params{"output"})){
		print STDERR "Doslo k chybe pri otevirani vystupniho souboru.\n";
		exit 3;
	}
	print OUTF $document."\n";
	close OUTF;
}
else {print $document."\n";}

########################################################################
#	FUNKCE REKURZIVNIHO SESTUPU BKG - reprezentuji jednotlive neterminaly
########################################################################
sub validateQuery($){
	my $paramsPtr = shift @_;
	my @words = splitQuery($paramsPtr);
	my $i = 0;
	my $i_ptr = \$i;
	
	($words[$i] eq "SELECT") or return 1;	
	$i++;
	$$paramsPtr{"element"} = $words[$i];
	$i++;

	limit($i_ptr, $paramsPtr);

	($words[$i] eq "FROM") or return 1;
	$i++;
		
	fromElement($i_ptr, $paramsPtr);
	if($$paramsPtr{"fromElement"} eq ""){
		return 1;
	}
	$i++;
	
	whereClause($i_ptr, $paramsPtr) and return 1;
	
	if(!$$paramsPtr{"root"}){
		$$paramsPtr{"root"} = $$paramsPtr{"element"}."s";
	}
	
	return 0;
}

sub limit($$){
	my ($i_ptr, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	if($words[$$i_ptr] eq "LIMIT"){
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
	
	#pokud mame zadany jenom atribut,hleda se pod rootem
	if((not $$paramsPtr{"fromElement"}) and $$paramsPtr{"fromAttribute"}){
		($$paramsPtr{"fromElement"} = "ROOT");
	}
	return 0;
}

sub whereClause($$){
	my ($i_ptr, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	($words[$$i_ptr] eq "WHERE") or return 0;
	$$i_ptr++;
	
	condition($i_ptr, $paramsPtr) and return 1;
	return 0;
}

sub condition($$){
	my ($i_ptr, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	if($words[$$i_ptr] eq "("){
		$$i_ptr++; 
		condition($i_ptr, $paramsPtr); 
		return 0;
	}
		
	if($words[$$i_ptr] eq "NOT"){			
		$$paramsPtr{"not"} = "defined";
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
	
	$$paramsPtr{"literal"} or return 1;
	($$paramsPtr{"whereElement"} or $$paramsPtr{"whereAttribute"}) or return 1;
	
	return 0;
}

sub relation($$){
	my ($i_ptr, $paramsPtr ) = @_;
	my @words = splitQuery($paramsPtr);
	
	$$paramsPtr{"cmp"}	= $words[$$i_ptr];
	$$i_ptr++;	
	if(($$paramsPtr{"cmp"} ne "=") and ($$paramsPtr{"cmp"} ne ">") and
	 ($$paramsPtr{"cmp"} ne "<") and $$paramsPtr{"cmp"} ne "CONTAINS"){
		return 1;
	}
	return 0;
}

########################################################################
#	POMOCNE FUNKCE
########################################################################

#rozdeleni dotazu na pole jednotlivych slov
sub splitQuery($){
	my $params = shift @_;
	my $query = $$params{"query"};
	return split(' ', $query);;
}

sub readXML($){
	my $paramsPtr = shift @_;	
	my $parser = XML::LibXML->new;
	my $fileContent;
	eval{$fileContent = $parser->parse_file($$paramsPtr{"input"})};
	if($@){
		print STDERR "Chyba pri nacitani vstupniho xml souboru.\n";
		exit 4;
	}	
	return $fileContent;
}

########################################################################
#	FUNKCE PRO ZPRACOVANI VLASTNIHO FILTROVANI DAT
########################################################################
sub findAttrs($$$){
	my($paramsPtr, $xmlNode, $foundNodes) = @_;
	
	if($xmlNode->hasAttributes()){
		my @attrs = $xmlNode->attributes();
		my $attr;
		foreach $attr (@attrs){
			if($attr->toString() =~ /$$paramsPtr{"fromAttribute"}.*/ ){
				@$foundNodes = $xmlNode;
				return 0;
			}
		}
	}
	
	if($xmlNode->hasChildNodes()){
		my @childnodes = $xmlNode->childNodes();
		my $node;
		foreach $node (@childnodes){
			findAttrs($paramsPtr, $node, $foundNodes);
		}
	}
	return 0;
}

sub elementSel($$$@){
	my ($paramsPtr, $documentPtr, $counter, @childnodes) = @_;
	
	my ($node, $attr);
	foreach $node (@childnodes){
		if($node->nodeName() eq $$paramsPtr{"element"}){
			if(evalRel($paramsPtr, $node)){ 
				if(defined($$paramsPtr{"limit"}) and ($$counter > int($$paramsPtr{"limit"}))){
					return 0;
				}
				$$documentPtr .= $node->toString();
				$$counter++;
			}    
		} 
		elsif($node->hasChildNodes()){
			elementSel($paramsPtr, $documentPtr, $counter, $node->childNodes());
		}
	}
	return 0;
}

sub evalRel($$){
	my ($paramsPtr, $node) = @_;	
	
	#podminka nebyla soucasti dotazu
	$$paramsPtr{"cmp"} or return 1;
	
	#rozhoduje se podle obsahu elementu
	if($$paramsPtr{"whereElement"}){
		my @childnodes = $node->childNodes();
		my $child;
		foreach $child (@childnodes){
			if($child->nodeName() eq $$paramsPtr{"whereElement"}){
				if($$paramsPtr{"cmp"} eq "<") {
					if($child->textContent() < int($$paramsPtr{"literal"})){
						$$paramsPtr{"not"}?return 0:return 1;
					} else { $$paramsPtr{"not"}?return 1:return 0;}
				}
				elsif($$paramsPtr{"cmp"} eq "="){
					if($child->textContent() eq $$paramsPtr{"literal"}){
						$$paramsPtr{"not"}?return 0:return 1;
					} else { $$paramsPtr{"not"}?return 1:return 0;}
				}
				elsif($$paramsPtr{"cmp"} eq ">"){
					if($child->textContent() > int($$paramsPtr{"literal"})){
						$$paramsPtr{"not"}?return 0:return 1;
					} else { $$paramsPtr{"not"}?return 1:return 0;}
				}
				elsif($$paramsPtr{"cmp"} eq "CONTAINS"){
					if($child->textContent() =~ /.*$$paramsPtr{"literal"}.*/ ){
						$$paramsPtr{"not"}?return 0:return 1;
					} else { $$paramsPtr{"not"}?return 1:return 0;}
				}
			}
		}
	}
	
	#rozhoduje se podle obsahu atributu
	if($$paramsPtr{"whereAttribute"}){
		my @attribs = $node->attributes();
		my $attr;
		foreach $attr (@attribs){
			if($attr->nodeName() eq $$paramsPtr{"whereAttribute"}){
				if($$paramsPtr{"cmp"} eq "<") {
					if($attr->toString() < int($$paramsPtr{"literal"})){
						$$paramsPtr{"not"}?return 0:return 1;
					} else { $$paramsPtr{"not"}?return 1:return 0;}
				}
				elsif($$paramsPtr{"cmp"} eq "="){
					if($attr->toString() eq $$paramsPtr{"literal"}){
						$$paramsPtr{"not"}?return 0:return 1;
					} else { $$paramsPtr{"not"}?return 1:return 0;}
				}
				elsif($$paramsPtr{"cmp"} eq ">"){
					if($attr->toString() > int($$paramsPtr{"literal"})){
						$$paramsPtr{"not"}?return 0:return 1;
					} else { $$paramsPtr{"not"}?return 1:return 0;}
				}
				elsif($$paramsPtr{"cmp"} eq "CONTAINS"){
					if($attr->toString() =~ /.*$$paramsPtr{"literal"}.*/ ){
						$$paramsPtr{"not"}?return 0:return 1;
					} else { $$paramsPtr{"not"}?return 1:return 0;}
				}
			}
		}
	}
	return 0;
}
