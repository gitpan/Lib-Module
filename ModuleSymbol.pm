package Lib::ModuleSymbol;
my $RCSRevKey = '$Revision: 0.52 $';
$RCSRevKey =~ /Revision: (.*?) /;
$VERSION=0.52;
use vars qw( @ISA @EXPORT @EXPORT_OK $VERSION );
push @ISA, qw( Exporter DB );

use DB;

=head1 NAME

Lib::ModuleSymbol.pm -- Lexical scanning of Perl library modules.

=head1 DESCRIPTION

Refer to the Lib::Module(3) manual page.

=head2 Running Under Perl/Tk

This module can call Tk::Event::DoOneEvent() function to provide
window updates.  The function usesTk() checks whether the this module
is called from a program that uses Perl/Tk and returns true if running
in a Tk::MainWindow, false if not.

=head1 REVISION

$Id: ModuleSymbol.pm,v 0.52 2000/09/19 21:28:06 kiesling Exp $

=head1 SEE ALSO

Refer to the manual pages: Lib::Module(3), Tk::Browser(3),
perlmod(1), perlmodlib(1), perl(1).

=cut

sub new {
  my $proto = shift;
  my $class = ref( $proto ) || $proto;
  my $self = {
	      pathname => undef,
	      packagename => undef,
	      version => undef,
	      refsymbols => []
	      };
  bless( $self, $class);
  return $self;

}

my @scannedpackages;

sub scannedpackages {
  if( @_ ) { @scannedpackages = @_ }
  return @scannedpackages;
}

sub text_symbols {
  my $p = shift;
  my (@text, $pathname) = @_;
  my @matches;
  my $nmatches;
  my $package;
  my @unsortedsymbols;
  my ($i, $j, $k);
  if ($text[0] =~ /^package/) { $package = $text[0] };
  $package =~ s/(^package\s+)|(\s*\;.*$)//g;
  chop $package;
  return undef unless $package;
  @matches = grep /$package/, @scannedpackages;
  return undef if ( $nmatches = @matches );
  @matches = grep /\$VERSION/, @text;
  $matches[0] =~ /(\$VERSION[ \t]*=[ \t]*(.*?)\;)/;
  my $ver = $2;
  $p -> {pathname} = $pathname;
  $p -> {packagename} = $package;
  $p -> {version} = $ver;
  # find subs;
  @{$p -> {refsymbols}} = grep /^sub\s+\S*?.*$/, @text;
  # find everything else
  @matches = grep /[\$\@\%]\w+/, @text;
  VARS: foreach $i ( @matches ) {
      $i =~ /([\$\@\%]\w+)/;
      $j = $1;
      foreach $k ( @{$p -> {refsymbols}} ) {
	next VARS if $k eq $j;  
      }
      push @{$p -> {refsymbols}}, ($j);
    }
  push @scannedpackages, ($package);
  return 1;
}

my %xrefcache;

sub xrefcache {
    my $self = shift;
    if (@_) { $self -> {xrefcache} = shift; }
    return $self -> {xrefcache}
}

sub xrefs {
  my $symobject = shift;
  my ($sym) = @_;
  my $key;
  my $modulepathname;
  my @packagefiles = ();
  my @text;
  my @matches;
  my $nmatches;
  my $i = 0;
  foreach $key ( keys %{*{"main\:\:"}} ) {
    if( $key =~ /^\_\<(.*)$/ ) {
      $modulepathname = $1;
      next if $modulepathname !~ /\.pm$/;
      if( $xrefcache{$modulepathname} ) {
	push @text, @{$xrefcache{$modulepathname}};
      } elsif( open MODULE, "<$modulepathname" ) {
	@text = <MODULE>;
	# weed out comments
	foreach (@text) { $_ =~ s/\#.*$// }
	close MODULE;
	push @{$xrefcache{$modulepathname}}, @text;
      }
      if ( &usesTk ) {
	&Tk::Event::DoOneEvent(255);
      }
      @matches = grep /$sym/, @text;
      $nmatches = @matches;
#      print "$sym: $nmatches match(es): in $modulepathname:\n";
#      foreach (@matches ) {print "   $_\n";}
      push @packagefiles, ($modulepathname) if ($nmatches > 0) ;
    }
  }
  return @packagefiles;
}

sub pathname {
    my $self = shift;
    if (@_) { $self -> {pathname} = shift; }
    return $self -> {pathname}
}

sub packagename {
    my $self = shift;
    if (@_) { $self -> {packagename} = shift; }
    return $self -> {packagename}
}

sub refsymbols {
    my $self = shift;
    if (@_) { $self -> {refsymbols} = shift; }
    return $self -> {refsymbols}
}

sub usesTk {
  return ( exists ${"main\:\:"}{"Tk\:\:"} );
}

1;

