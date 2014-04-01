#!/usr/pkg/bin/perl 
## httpd
## 

use Socket;
use strict;
no strict "refs";
use IO::Socket;

#set values that can be changed in the .ini file
my ($HTTPPORT) = 80;
my ($PROTO) = 'tcp';
my ($MAXCONNECTIONS) = 5;
my ($LOCALHOSTNAME) = '192.168.0.203';
my ($STARTHTMLPAGE) = '/usr/local/bin/index.html';
my ($BADREQUEST);
my ($NOTFOUND);
my ($LOGFILE) = '/usr/local/bin/logfile.txt';
my ($BACKUP) = 0;

my ($httphandle , $errorlog , $argv_ident_counter , $stdin , $print_info , $temp_hard_ref);
my ($accept_addr , $accept_ip);
my ($newprocess);
my ($command , $arg1 , $arg2 , $arg3 , $arg4);
my ($sig_got, $sock , $filedata , $perl_output);
my ($request);

$SIG{'INT'} = \&exit_clean;
$SIG{'QUIT'} = \&exit_clean;
$SIG{'CHLD'} = \&child_handler;

OUTER:
for ($argv_ident_counter = 0 ; $argv_ident_counter < @ARGV ; $argv_ident_counter++){  
  if (@ARGV[$argv_ident_counter] eq "-f"){
      $errorlog = @ARGV[$argv_ident_counter + 1];
  }elsif(@ARGV[$argv_ident_counter] eq "-info"){
	$print_info = 1;
  }elsif(@ARGV[$argv_ident_counter] eq "-?"){
	help();
  }elsif(@ARGV[$argv_ident_counter] eq "-h") {
	help();
  }
}



#open up the .ini file
print "Reading values from config.ini...\n";


open(CONFIG , "config.ini") || print "config.ini is not in same dir, using defaults...\n";
while(<CONFIG>)
{
    next unless ! m/^(\s)*#/;
    
    if( m/\s*([a-zA-Z0-9\.!@#$%^&\/|-]+)\s?=\s?([a-zA-Z0-9\.!@#$%^&\/|-]+)\s*/ )
    {
    
	if( $1 eq "HTTPPORT"       ) { $HTTPPORT       = $2 };
	if( $1 eq "PROTO"          ) { $PROTO          = $2 };
	if( $1 eq "MAXCONNECTIONS" ) { $MAXCONNECTIONS = $2 };
	if( $1 eq "LOCALHOSTNAME " ) { $LOCALHOSTNAME  = $2 };
	if( $1 eq "STARTHTMLPAGE"  ) { $STARTHTMLPAGE  = $2 };
	if( $1 eq "BADREQUEST"     ) { $BADREQUEST     = $2 };
	if( $1 eq "NOTFOUND"       ) { $NOTFOUND       = $2 };
	if( $1 eq "LOGFILE"        ) { $LOGFILE        = $2 };
	if( $1 eq "BACKUP"         ) { $BACKUP         = $2 };
    }
}
close(CONFIG) || print "could not close config.ini, is it in the same dir?\n";


#set default values that can be changed in the .ini file

if ($BACKUP)
{

    open(CONFIG , "<config.ini") || print "cannot open config file for reading.\n"; 
    open(FILE , "+>config.old") || print "cannot open backup file for writing.\n";

    print FILE "#This file is a backup config.ini file.\n";

    while(<CONFIG>){
	   print FILE $_;
    }

    close(FILE) || print "cannot close backup file.\n";
    close(CONFIG) || print "cannot close config file.\n";

}

print <<ETOF if $print_info;


Local Host Name   : $LOCALHOSTNAME
Local Server Port : $HTTPPORT
Protocol	  : $PROTO
Max Connections   : $MAXCONNECTIONS

Default HTML Page : $STARTHTMLPAGE


ETOF
exit(1) if $print_info;

$errorlog  = $errorlog || $LOGFILE;

$httphandle = new IO::Socket::INET( 
	LocalHost => $LOCALHOSTNAME,
	LocalPort => $HTTPPORT,
	Proto	=> $PROTO,
	Listen	=> $MAXCONNECTIONS,
	Reuse	=> 1
	);

unless ($httphandle)
{
   die("error, quitting... $0");
}

autoflush $httphandle 1;

print "HTTP Server started\n";

if ($errorlog){
    print "Logging errors to $errorlog...\n";
    open(ERRORLOG , "$errorlog") || die("Cannot find $errorlog!\n");
}



## accept connections...

while(1){

    A_CONNECTION:
    {
    	$accept_addr = accept(CHLDSOCK , $httphandle) || redo A_CONNECTION;
    }

    autoflush CHLDSOCK 1;

    $newprocess = fork();

    print ERRORLOG "cannot fork!\n" if $errorlog;
    die("cannot fork!\n") unless defined($newprocess);

    if($newprocess == 0){
	if($accept_addr){
	
	    
	    ##we have to change the directory now to the dir that is in the .ini file.
	
	
	    $accept_ip = inet_ntoa((unpack_sockaddr_in($accept_addr))[1]);
	    print ERRORLOG "Accepted connection from $accept_ip\n" if $errorlog;
	    print "Accepted connection from $accept_ip\n";
	    chomp($request = <CHLDSOCK>);
	
	    print $request . "\n";
	
	    
	    unless($request =~ m/(\S+) (\S+)/g) {
		
		print ERRORLOG "Invalid request string from $accept_ip\n" if $errorlog;
		print "Invalid request string from $accept_ip\n";	
		#bad_request(*CHLDSOCK);    
	
	    }
	    else{
		
	    	$command = $1;
		($arg1, $arg2 , $arg3 , $arg4) = $2 , $3 , $4 , $5;
	
		if ( uc($command) eq "GET" ){
	
		    if ($arg1 eq '/'){
			   
	
			print CHLDSOCK "HTTP/1.1 301 Moved Permanently" . "\n";
			print CHLDSOCK "Location: http://440bx.wordpress.com" . "\n\n";
	
	
		    close(CHLDSOCK);
		    next;
	
		    }
		    
		}
	    	
	    }
	    close(CHLDSOCK);
	    
	    exit(0);
	
	    
	}
	close(CHLDSOCK);

  }

}




sub bad_request(){

$sock = shift;

	unless ($BADREQUEST){

		print $sock <<ETOF;
		<html>
		<head>
		<title>Invalid Request String</title>
		</head>
		<body>
		<h1>Malformed Request String</h1>
		Command not recognized.
		</body>
		</html>

ETOF

	}
	else{
		open(FILE , "$BADREQUEST") || die('cannot find file specified by NOTFOUND in config.ini!\n');
		print while(<FILE>);
		close(FILE);
	}

}


sub not_found(){

$sock = shift;

	unless($NOTFOUND){

		print $sock <<ETOF;
		<HTML>
		<HEAD>
		<TITLE>File Not Found</TITLE>
		</HEAD>
		<BODY>
		<H1>404 File Not Found</H1>
		The file you requested could not be found on this server.
		</BODY>
		</HTML>

ETOF

	}
	else{
		open(FILE , "$NOTFOUND") || die('cannot find file specified by NOTFOUND in config.ini!\n');
		print while(<FILE>);
		close(FILE);
	}

}


sub exit_clean(){

	close(ERRORLOG);
	$sig_got = @_;
	$SIG{'INT'}  = 'IGNORE';
	$SIG{'QUIT'} = 'IGNORE';
	close(SERVERSOCK);
	close(CHLDSOCK);
	
	if ($errorlog) { print ERRORLOG "Quitting on signal $sig_got"};
	die("Quitting on signal $sig_got\n");

}


sub child_handler(){
	wait;
}


sub help(){

print "help";

}

