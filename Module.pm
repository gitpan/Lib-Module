package Lib::Module;
# $Id: Module.pm,v 1.13 2004/03/28 02:22:23 kiesling Exp $
$VERSION=0.69;
use vars qw( @ISA @EXPORT @EXPORT_OK $VERSION );
push @ISA, qw(Exporter);

@EXPORT_OK = qw($VERSION &libdirs &module_paths &scanlibs &retrieve 
		&pathname &usesTk &ModuleVersion &PathName &BaseName
		&PackageName &Supers);

require Exporter;
require Carp;
use File::Basename;
use Lib::ModuleSymbol;
use Lib::SymbolRef;
use IO::Handle;
use DB;

my @modulepathnames;
my @libdirectories;

=head1 Lib::Module.pm - Perl library module utilities.

=head1 SYNOPSIS

  use Lib::Module;

  my $m = new Lib::Module;  # Create a module object.

  # Create the class library hierarchy.
  $m -> libdirs ($verbose); 
  $m -> module_paths ($verbose);
  $m -> scanlibs ($verbose);

  # Retrieve the module object for a package.
  my $m2 = $m -> retrieve ("Tk::Browser");

  print $m2 -> PathName . "\n" . 
	$m2 -> BaseName . "\n" .
	$m2 -> PackageName . "\n" .
	$m2 -> ModuleVersion . "\n" .
        $m2 -> Supers . "\n";

  # Return the file path name of a module.
  my $path = $m -> pathname ("Tk::Browser");



=head1 DESCRIPTION

A Lib::Module object describes a Perl library module and includes the
module's package name, file name, version, and superclasses, if any.

The module objects are normally part of a class hierarchy generated by
libdirs (), module_paths (), and scanlibs ().  Every module is a
subclass of UNIVERSAL, Perl's default superclass.

=head1 METHODS

=head2 ModuleVersion

Return the module's b<$VERSION => line.

=head2 PathName ($name)

Return the module's path.

=head2 BaseName ($name)

Return the module's file basename.

=head2 PackageName ($name)

Return the argument of the module's B<package> function.

=head2 retrieve (I<basename> || I<packagename>)

The retrieve ($name) method returns the Lib::Module object or undef.

  my $new = $m -> retrieve ("Optional::Module");

  if (!defined $new) {
     print "Can't find Optional::Module.\n"
  }

B<Retrieve> matches the first part of the module's name.  If B<retrieve>
doesn't match a sub-module, specify only the sub-module's name; e.g.,
'Module' instead of 'Optional::Module'.

=head2 Supers ()

Returns the module's superclasses; i.e, the arguments of an @ISA
declaration.

=head1 EXPORTS

See the @EXPORTS_OK array.

=head1 BUGS

Does not take into account all of the possible module naming schemes
when retrieving modules.

=head1 VERSION

VERSION 0.69

=head1 COPYRIGHT

Copyright � 2001-2004 Robert Kiesling, rkies@cpan.org.

Licensed under the same terms as Perl.  Refer to the file,
"Artistic," for information.

=head1 SEE ALSO

perl(1), Tk::Browser(3)

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
no warnings;
sub retrieve {
    my $parent = shift;
    my ($n) = @_;
    if ( $parent -> {basename}  =~ /^$n$/  || $_ -> {packagename} =~ /^$n$/) { 
	return $parent; 
    }
    foreach ( @{$parent -> {children}} ) {
	return $_ 
	    if ( $_ -> {basename} =~ /^$n$/ || $_ -> {packagename} =~ /^$n/);
    } 
    foreach ( @{$parent -> {children}}  && $_ -> {packagename} =~ /^$n/) {
	return $_ if (retrieve( $_, $n ));
    }
    return undef;
}
use warnings;

sub pathname {
    my $self = shift;
    my $name = $_[0];
    my $verbose = $_[1];
    autoflush STDOUT 1 if $verbose;
    if ($self -> {basename} =~ /^$name/ || $self->{packagename} =~ /^$name/) { 
	return $self -> {pathname}; }
    foreach ( @{$self -> {children}} ) {
      print '.' if $verbose;
	if ($_ -> {basename} =~ /^$name/ || $self->{packagename} =~ /^$name/) {
	    return $_ -> {pathname};
	}
    } 
    foreach ( @{$self -> {children}} ) {
	if ( pathname ( $_, $name ) ) { 
	    return $_ -> {pathname}; }
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
    if ( $parent -> {packagename}  eq $n ) { 
	return $parent; }
    foreach ( @{$parent -> {children}} ) {
	if ( $_ -> {packagename} eq $n ) {
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
    my $self = shift;
    return @modulepathnames;
}

sub libdirectories {
    my $self = shift;
    return @libdirectories;
}

sub scanlibs {
    my $b = shift;
    my $verbose = $_[0];
    my $m;
    my ($path, $bname, $ext);
    autoflush STDOUT 1 if $verbose;
  LOOP: foreach my $i ( @modulepathnames ) {
      print '.' if $verbose;
      ($bname, $path, $ext) = fileparse($i, qw(\.pm$ \.pl$) );
      # Don't use RCS Archives or Emacs bacups
      if( $bname =~ /(,v)|~/ ) { next LOOP; }
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
    my ($supers, $pkg, $ver, @text, @matches); 
    ($bname, $dirs, $ext) = fileparse($path, qw(\.pm \.pl));
    $self -> {pathname} = $path;
    @text = $self -> readfile;
    my $p = new Lib::ModuleSymbol;
    $p -> {pathname} = $path; 
    $p -> text_symbols( @text );
    $self -> {version} = $p -> {version} if $p -> {version};
    $self -> {moduleinfo} = $p ;
    $self -> {packagename} = $p -> {packagename};
    # We do a static match here because it's faster
    # Todo: include base classes from "use base" statements.#
    @matches = grep /^(our|my|push)+\s+\@ISA(.*?)\;/, @text;
    $supers = $matches[0];
    $supers =~ s/\@ISA|push|our|my|(qw)|[=\(\)\;]//gms if $supers;
    $supers =~ s/\W*// if $supers;
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
      next unless $key;
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
	if($key =~ /ISA/ ) {
	  $m -> {superclasses} = "@{*v{ARRAY}}";
	}
      }
    }
    $keylist{$key} = ${*{"$pkg"}}{$key} if $key;
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
  if (@_){ ($fn) = @_; } else { $fn = $self -> PathName; }
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
    my $self = shift;
    my $verbose = $_[0];
    my $f; my $f2;
    my $d; 
    autoflush STDOUT 1 if $verbose;
    foreach $d ( @INC ) {
	push @libdirectories, ($d);
	print '.' if $verbose;
	opendir DIR, $d;
	@dirfiles = readdir DIR;
	closedir DIR;
	# look for subdirs of the directories in @INC.
	foreach $f ( @dirfiles ) {
	    next if $f =~ m/^\.{1,2}$/ ;
	    $f2 = $d . '/' . $f;
	    if (opendir SUBDIR, $f2 ) {
		push @libdirectories, ($f2);
		print '.' if $verbose;
		libsubdir( $f2 );
		closedir SUBDIR;
	    }
	}
    }
}

sub libsubdir {
    my ($parent) = @_;
    opendir DIR, $parent;
    my @dirfiles = readdir DIR;
    closedir DIR;
    foreach (@dirfiles) {
	next if $_ =~ m/^\.{1,2}$/ ;
	my $f2 = $parent . '/' . $_;
	if (opendir SUBDIR, $f2 ) {
	    push @libdirectories, ($f2);
	    print '.' if $verbose;
	    libsubdir( $f2 );
	    closedir SUBDIR;
	}
    }
}

sub module_paths {
    my $self = shift;
    my ($f, $pathname, @allfiles);
    foreach ( @libdirectories ) {
	opendir DIR, $_;
	@allfiles = readdir DIR;
	closedir DIR;
	foreach $f ( @allfiles ) {
	    if ( $f =~ /\.p[lm]/ ) {
		$pathname = $_ . '/' . $f;
		push @modulepathnames, ($pathname);
	    }
	}
    }
}

sub Children {
    my $self = shift;
    if (@_) { $self -> {children} = shift; }
    return $self -> {children}
}

sub Parents {
    my $self = shift;
    if (@_) { $self -> {parents} = shift; }
    return $self -> {parents}
}

sub PathName {
    my $self = shift;
    if (@_) { $self -> {pathname} = shift; }
    return $self -> {pathname}
}

sub BaseName {
    my $self = shift;
    if (@_) { $self -> {basename} = shift; }
    return $self -> {basename}
}

sub ModuleVersion {
    my $self = shift;
    return $self -> {moduleinfo} -> {version};
}

sub PackageName {
    my $self = shift;
    if (@_) { $self -> {packagename} = shift; }
    return $self -> {packagename}
}

sub Symbols {
    my $self = shift;
    if (@_) { $self -> {symbols} = shift; }
    return $self -> {symbols}
}

###
### Version, SuperClass -- Module.pm uses hashref directly.
###
sub Version {
    my $self = shift;
    if (@_) { $self -> {version} = shift; }
    return $self -> {version}
}

sub SuperClasses {
    my $self = shift;
    if (@_) { $self -> {superclasses} = shift; }
    return $self -> {superclasses}
}

sub BaseClass {
    my $self = shift;
    if (@_) { $self -> {baseclass} = shift; }
    return $self -> {baseclass}
}

sub ModuleInfo {
    my $self = shift;
    if (@_) { $self -> {moduleinfo} = shift; }
    return $self -> {moduleinfo}
}

sub Supers {
    my $self = shift;
    return $self -> {superclasses};
}

sub Import {
  my ($pkg) = @_;
  &Exporter::import( $pkg ); 
}

1;

