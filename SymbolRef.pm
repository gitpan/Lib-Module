package Lib::SymbolRef;
my $RCSRevKey = '$Revision: 0.51 $';
$RCSRevKey =~ /Revision: (.*?) /;
$VERSION=0.51;
use vars qw( @ISA @EXPORT @EXPORT_OK $VERSION );
push @ISA, qw( Exporter DB );
@EXPORT_OK=qw($VERSION);

require Exporter;
require Carp;
use Lib::ModuleSym;
use DB;

=head1  NAME

  Tk::Symbolref.pm -- Manage tied references to symbol table hash
  entries.

=head1 SYNOPSIS

  use Lib::Module;
  use Lib::ModuleSym;
  use Lib::SymbolRef;

  tie *Package::symbol, 'Lib::SymbolRef, 

=head1 DESCRIPTION

Much room for further expansion using these methods.

=head1 REVISION

$Id: SymbolRef.pm,v 0.51 2000/09/18 20:23:59 kiesling Exp kiesling $

=head1 SEE ALSO

The manual pages for Lib::Module(3), Tk::Browser(3), perltie(1).

=cut

sub TIESCALAR {
  my ($package, $name, $refer) = @_;
  my $obj = { name => $name, refs=>() };
  bless $obj, $package;
  return $obj;
}

sub TIEHANDLE {
  my ($package, $name, $refer) = @_;
  my $obj = { name => $name, refs => () };
  bless $obj, $package;
  return $obj;
}

sub TIEARRAY {
}

sub PRINTF {
  my $self = shift;
  my $fmt = shift;
}

sub FETCH {
  return undef;
}

sub GETC {
  return undef;
}

sub READ {
  return undef;
}

sub OPEN {
  return undef;
}

sub READLINE {
  return undef;
}

sub STORE {
  return undef;
}


# ---- Hash methods -----


sub TIEHASH {
  my ($varref, $package, $callingpkg ) = @_;
  my $obj = [ name => $varref, callingpkg => $callingpkg, {%$hr} ];
  bless $obj, $package;
  print "TIEHASH: $varref, $package, $callingpkg\n";
  return $obj;
}

sub FIRSTKEY {
}

sub CLEAR {
}

# ---- Instance methods

sub name {
  my $self = shift;
  if (@_) {
    $self -> {name} = shift;
  }
  return $self -> {name}
}

1;

