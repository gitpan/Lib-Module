package Lib::Module;
my $RCSRevKey = '$Revision: 0.65 $';
$RCSRevKey =~ /Revision: (.*?) /;
$VERSION=0.65;
use vars qw( @ISA @EXPORT @EXPORT_OK $VERSION );
push @ISA, qw( Tk Exporter DB );
# @EXPORT=qw($VERSION);

require Exporter;
require Carp;
use File::Basename;
use Lib::ModuleSym;
use Lib::SymbolRef;
use DB;

my @modulepathnames;
my @libdirectories;

=head1 Lib::Module.pm

=head1 SYNOPSIS

  use Lib::Module;
  use Lib::ModuleSym;
  use Lib::SymbolRef;

=head1 DESCRIPTION

Provides a hierarchical object reference for a Perl library module,
including the package name, file name, version, an array of stash
references, and superclasses, if any.

Module objects can be stored in a tree similar to the Perl class
hierarchy.  At this time, the hierarchy tree used is only two deep,
because of the many different ways modules can communicate with each
other.  Every module is a subclass of UNIVERSAL, which is the 
default abstract superclass of all Perl packages.

The Lib::ModuleSym.pm module provides lexical scanning and 
lookup, and provides cross referencing subroutines.

The Lib::SymbolRef module provides tied objects that correspond
to stash references, but this needs to be expanded.

=head2 Running Under Perl/Tk

This module can call Tk::Event::DoOneEvent() function to provide
window updates.  The function usesTk() checks whether the this module
is called from a program that uses Perl/Tk and returns true if running
in a Tk::MainWindow, false if not.

=head1 REVISION

$Id: Module.pm,v 0.65 2000/09/19 21:27:15 kiesling Exp $

=head1 SEE ALSO

The manual pages: Tk::Browser(3), perlmod(1), perlmodlib(1), perl(1).

=cut

sub new {
    my $proto = shift;
    my $class = ref( $proto ) || $proto;
    my $self = {
	children => [],
	parents => '',
	pathname => '',
	basename => '',
	packagename => '',
	version => '',
	superclasses => undef,  
	baseclass => '',
	moduleinfo => undef,
	symbols => []
	};
    bless( $self, $class);
    return $self;
}

# Given a file base name, return the Module object.
sub retrieve {
    my $parent = shift;
    my ($n) = @_;
    if ( $parent -> {basename}  =~ /^$n/ ) { 
	return $parent; }
    foreach ( @{$parent -> {children}} ) {
	if ( $_ -> {basename} =~ /^$n/ ) {
	    return $_;
	}
    } 
    foreach ( @{$parent -> {children}} ) {
	if ( retrieve( $_, $n ) ) { 
	    return $_; }
    }
    return undef;
}

# Given a module package or sub-package name, return the module object.
# It's probably desirable to use this in preference to retrieve, 
# with external calls, to avoid dealing with the library pathnames 
# unless necessary.
sub retrieve_module {
    my $parent = shift;
    my ($n) = @_;
    if ( $parent -> {packagename}  =~ /^$n/ ) { 
	return $parent; }
    foreach ( @{$parent -> {children}} ) {
	if ( $_ -> {packagename} =~ /^$n/ ) {
	    return $_;
	}
    } 
    foreach ( @{$parent -> {children}} ) {
	if ( retrieve( $_, $n ) ) { 
	    return $_; }
    }
    return undef;
}

sub modulepathnames {
    return @modulepathnames;
}

sub libdirectories {
    return @libdirectories;
}

sub scanlibs {
    my $b = shift;
    my $m;
    my ($path, $bname, $ext);
  LOOP: foreach my $i ( @modulepathnames ) {
      ($bname, $path, $ext) = fileparse($i, qw(\.pm$ \.pl$) );
      # Don't use RCS Archives or Emacs bacups
      if( $bname =~ /(,v)|~/ ) { next LOOP; }
      if( &usesTk ) {
	&Tk::Event::DoOneEvent(255);
      }
      &Lib::ModuleSym::scannedpackages(());
      if( $bname =~ /UNIVERSAL/ ) {
	  $b -> modinfo( $i );
      } else {
	  $m = new Lib::Module;
	  next LOOP if ! $m -> modinfo( $i );
	  $m -> {parents} = $b; 
	  push @{$b -> {children}}, ($m); 
      }
  }
}

sub modinfo {
    my $self = shift;
    my ($path) = @_;
    my ($dirs, $bname, $ext);
    my $supers;
    my $pkg;
    my $ver;
    my @text; 
    my @matches;
    ($bname, $dirs, $ext) = fileparse($path, qw(\.pm \.pl));
    $self -> {pathname} = $path;
    @text = $self -> readfile;
    my $p = new Lib::ModuleSym;
    return undef if ! $p -> text_symbols( @text, $path );
    $self -> {moduleinfo} = $p ;
    $self -> {packagename} = $p -> {packagename};
    $self -> {version} = $p -> {version};
    # We do a static match here because it's faster
    # Todo: include base classes from "use base" statements.
    @matches = grep /^\@ISA(.*?)\;/, @text;
    $supers = $matches[0];
    $supers =~ s/(qw)|[=\(\)\;]//gms;
    $self -> {basename} = $bname;
    $self -> {superclasses} = $supers;
    return 1;
}

# See the perlmod manpage
# Returns a hash of symbol => values.
# Handles as separate ref.
# Typeglob dereferencing deja Symdump.pm and dumpvar.pl, et al.
# Package namespace creation and module loading per base.pm.
sub exportedkeys {
    my $m = shift;
    my ($pkg) = @_;
    my $obj;
    my $key; my $val;
    my $rval;
    my $nval;
    my %keylist = ();
    $m -> {symbols} = ();
    my @vallist;
    my $i = 0;
  EACHKEY: foreach $key( keys %{*{"$pkg"}} ) {
      if( defined ($val = ${*{"$pkg"}}{$key} ) ) {
        $rval = $val; $nval = $val; 
	$obj = tie $rval, 'Lib::SymbolRef', $nval;
	push @{$m -> {symbols}}, ($obj);
	foreach( @vallist) { if ( $_ eq $rval ) { next EACHKEY } }
	# Replace the static $VERSION and @ISA values 
	# of the initial library scan with the symbol
	# compile/run-time values.
	local (*v) = $val;
	# Look for the stash values in case they've changed 
	# from the source scan.
	if( $key =~ /VERSION/ ) {
	  $m -> {version} = ${*v{SCALAR}};
	}
	if( $key =~ /ISA/ ) {
	  $m -> {superclasses} = "@{*v{ARRAY}}";
	}
      }
    }
    $keylist{$key} = ${*{"$pkg"}}{$key};
    # for dumping symbol refs to STDOUT.
    # example of how to print listing of symbol refs.
#    foreach my $i ( @{$m -> {symbols}} ) { 
#      foreach( @{$i -> {name}} ) {
#	print $_; 
#      }
#      print "\n--------\n";
#    }
    return %keylist;
}

#
#  Here for example only.  This function (or the statements
# it contains), must be in the package that has the main:: stash
# space in order to list the packages symbols into the correct
# stash context.  
#
# sub modImport {
#  my ($pkg) = @_;
#  eval "package $pkg";
#  eval "use $pkg";
#  eval "require $pkg";
#}

sub readfile {
  my $self = shift;
  my $fn;
  if (@_){ ($fn) = @_; } else { $fn = $self -> pathname; }
  my @text;
  open FILE, $fn or warn "Couldn't open file $fn: $!.\n";
  @text = <FILE>;
  close FILE;
  return @text;
}

# de-allocate module and all its children
sub DESTROY ($) {
    my ($m) = @_;
    @c = $m -> {children};
    $d = @c;
    if ( $d == 0 )  {   
	$m = {
	    children => undef
	};
	return;
      }
    foreach my $i ( @{$m -> {children}} ) {
	Lib::Module -> DESTROY($i);
    }
  }

sub libdirs {
    my $f; my $f2;
    my $d; 
    foreach $d ( @INC ) {
	push @libdirectories, ($d);
	opendir DIR, $d;
	@dirfiles = readdir DIR;
	closedir DIR;
	# look for subdirs of the directories in @INC.
	foreach $f ( @dirfiles ) {
	    next if $f =~ m/^\.{1,2}$/ ;
	    $f2 = $d . '/' . $f;
	    if (opendir SUBDIR, $f2 ) {
		push @libdirectories, ($f2);
		&libsubdir( $f2 );
		closedir SUBDIR;
	    }
	}
    }
}

sub libsubdir {
    my ($parent) = @_;
    opendir DIR, $d;
    my @dirfiles = readdir DIR;
    closedir DIR;
    foreach (@dirfiles) {
	next if $_ =~ m/^\.{1,2}$/ ;
	my $f2 = $d . '/' . $_;
	if (opendir SUBDIR, $f2 ) {
	    push @libdirectories, ($f2);
	    &libsubdir( $f2 );
	    closedir SUBDIR;
	}
    }
}

sub module_paths {
    my $self = shift;
    my $f;
    my $pathname;
    my $ftype;
    my @allfiles;
    my @files;
    my @matched_paths;
    my $n_matches;
    if( usesTk ) {
      &Tk::Event::DoOneEvent(255);
    }
    foreach ( @libdirectories ) {
	opendir DIR, $_;
	@allfiles = readdir DIR;
	closedir DIR;
	foreach $f ( @allfiles ) {
	    if ( $f =~ /\.p[lm]/ ) {
		$pathname = $_ . '/' . $f;
#		push @files, ($pathname);
		push @modulepathnames, ($pathname);
	    }
	}
#	push @modulepathnames, @files;
    }
}


#
# Instance data methods.  Refer to the perltoot man page.
#
sub children {
    my $self = shift;
    if (@_) { $self -> {children} = shift; }
    return $self -> {children}
}

sub parents {
    my $self = shift;
    if (@_) { $self -> {parents} = shift; }
    return $self -> {parents}
}

sub pathname {
    my $self = shift;
    if (@_) { $self -> {pathname} = shift; }
    return $self -> {pathname}
}

sub basename {
    my $self = shift;
    if (@_) { $self -> {basename} = shift; }
    return $self -> {basename}
}

sub packagename {
    my $self = shift;
    if (@_) { $self -> {packagename} = shift; }
    return $self -> {packagename}
}

sub symbols {
    my $self = shift;
    if (@_) { $self -> {symbols} = shift; }
    return $self -> {symbols}
}

sub version {
    my $self = shift;
    if (@_) { $self -> {version} = shift; }
    return $self -> {version}
}

sub superclasses {
    my $self = shift;
    if (@_) { $self -> {superclasses} = shift; }
    return $self -> {superclasses}
}

sub baseclass {
    my $self = shift;
    if (@_) { $self -> {baseclass} = shift; }
    return $self -> {baseclass}
}

sub moduleinfo {
    my $self = shift;
    if (@_) { $self -> {moduleinfo} = shift; }
    return $self -> {moduleinfo}
}

sub import {
  my ($pkg) = @_;
  &Exporter::import( $pkg ); 
}

sub usesTk {
  return ( exists ${"main\:\:"}{"Tk\:\:"} );
}

1;

