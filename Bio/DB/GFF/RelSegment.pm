package Bio::DB::GFF::RelSegment;

use strict;

use Bio::DB::GFF::Feature;
use Bio::DB::GFF::Util::Rearrange;
use Bio::DB::GFF::Segment;

use vars qw($VERSION @ISA);
@ISA = qw(Bio::DB::GFF::Segment);
$VERSION = '0.25';

use overload '""' => 'asString',
             'bool' => sub { overload::StrVal(shift) } ;

# Create a new Ace::Sequence::DBI::Segment object
# arguments are:
#      -factory    => factory and DBI interface
#      -seq        => $sequence_name
#      -start      => $start_relative_to_sequence
#      -stop       => $stop_relative_to_sequence
#      -ref        => $sequence which establishes coordinate system
#      -offset     => 0-based offset relative to sequence
#      -length     => length of segment
sub new {
  my $package = shift;
  my ($factory,$name,$start,$stop,$refseq,$class,$refclass,$offset,$length) =
    rearrange([
	       'FACTORY',
	       [qw(NAME SEQ SEQUENCE SOURCESEQ)],
	       [qw(START BEGIN)],
	       [qw(STOP END)],
	       [qw(REFSEQ REF REFNAME)],
	       [qw(CLASS SEQCLASS)],
	       qw(REFCLASS),
	       [qw(OFFSET OFF)],
	       [qw(LENGTH LEN)],
	     ],@_);

  $package = ref $package if ref $package;

  $factory or $package->throw("new(): provide a -factory argument");

  # partially fill in object
  my $self = bless { factory => $factory },$package;

  # if the class of the landmark is not specified then default to 'Sequence'
  $class ||= 'Sequence';

  # confirm that indicated sequence is actually in the database!
  my($absref,$absclass,$absstart,$absstop,$absstrand) = $factory->abscoords($name,$class)
    or return;

  # an explicit length overrides start and stop
  if (defined $offset) {
    warn "new(): bad idea to call new() with both a start and an offset"
      if defined $start;
    $start = $offset+1;
  }
  if (defined $length) {
    warn "new(): bad idea to call new() with both a stop and a length"
      if defined $stop;
    $stop = $start + $length - 1;
  }

  # this allows a SQL optimization way down deep
  $self->{whole}++ if $absref eq $name and !defined($start) and !defined($stop);

  $start = 1                    unless defined $start;
  $stop  = $absstop-$absstart+1 unless defined $stop;
  $length = $stop - $start + 1;

  # now offset to correct subsegment based on desired start and stop
  if ($absstrand eq '+') {
    $start =  $absstart + $start - 1;
    $stop  =  $start    + $length - 1;
  } else {
    $start =  $absstop - ($start - 1);
    $stop  =  $absstop - ($stop - 1);
  }
  @{$self}{qw(sourceseq start stop strand class)}
    = ($absref,$start,$stop,$absstrand,$absclass);

  # but what about the reference sequence?
  if (defined $refseq) {
    $refclass ||= 'Sequence';
    my ($refref,$refstart,$refstop,$refstrand) = $factory->abscoords($refseq,$refclass);
    unless ($refref eq $absref) {
      $self->error("reference sequence is on $refref but source sequence is on $absref");
      return;
    }
    $refstart = $refstop if $refstrand eq '-';
    @{$self}{qw(ref refstart refstrand)} = ($refseq,$refstart,$refstrand);
  } else {
    $absstart = $absstop if $absstrand eq '-';
    @{$self}{qw(ref refstart refstrand)} = ($name,$absstart,$absstrand);
  }

  return $self;
}

sub new_from_segment {
  my $package   = shift;
  $package      = ref $package if ref $package;
  my $segment   = shift;
  my $new = {};
  @{$new}{qw(factory sourceseq start stop strand class ref refstart refstrand)}
    = @{$segment}{qw(factory sourceseq start stop strand class ref refstart refstrand)};
  return bless $new,$package;
}

# read-only accessors
sub factory { shift->{factory} }

# start, stop, length
sub start {
  my $self = shift;
  $self->abs2rel($self->{start});
}
sub stop {
  my $self = shift;
  $self->abs2rel($self->{stop});
}

sub abs_ref    { shift->{sourceseq}   }
sub abs_start  { shift->{start} }
sub abs_stop   { shift->{stop}  }
sub abs_strand { shift->{refstrand} }

sub length {
  my $self = shift;
  abs($self->abs_stop - $self->abs_start) + 1;
}

sub refseq {
  my $self = shift;
  my $g    = $self->{ref};
  if (@_) {
    my $newref   = shift;
    my $newclass = shift || 'Sequence';
    my ($refref,$refstart,$refstop,$refstrand)
      = $newref->isa('Bio::DB::GFF::RelSegment') ? ($newref->refseq,$newref->abs_start,$newref->abs_stop,$newref->abstrand)
                                                 : $self->factory->abscoords($newref,$newclass);
    $self->throw("can't set reference sequence: $newref and $self are on different sequence segments")
      unless $refref eq $self->{sourceseq};
    @{$self}{qw(ref refstart refstrand)} = ($newref,$refstart,$refstrand);
  }
  return $self->absolute ? $self->sourceseq : $g;
}

sub asString {
  my $self = shift;
  my $label = $self->{absolute} ? $self->{sourceseq} : $self->{ref};
  my $start = $self->start || '';
  my $stop  = $self->stop  || '';
  return "$label:$start,$stop";
}

sub absolute {
  my $self = shift;
  my $g = $self->{absolute};
  $self->{absolute} = shift if @_;
  $g;
}

sub dna {
  my $self = shift;
  my ($ref,$start,$stop,$strand,$class) 
    = @{$self}{qw(sourceseq start stop strand class)};
  ($start,$stop) = ($stop,$start) if $strand eq '-';
  $self->factory->dna($ref,$class,$start,$stop);
}

# return all features that overlap with this segment;
# optionally modified by a list of types to filter on
sub features {
  my $self = shift;
  my @args = $self->_process_feature_args(@_);
  return $self->factory->overlapping_features(@args);
}

# return all features completely contained within this segment
sub contained_features {
  my $self = shift;
  my @args = $self->_process_feature_args(@_);
  return $self->factory->contained_features(@args);
}

sub _process_feature_args {
  my $self = shift;
  my ($ref,$class,$start,$stop,$strand,$whole)
    = @{$self}{qw(sourceseq class start stop strand whole)};

  ($start,$stop) = ($stop,$start) if $strand eq '-';

  my @args = (-ref=>$ref,-class=>$class);

  # indicating that we are fetching the whole segment allows certain
  # SQL optimizations.
  push @args,(-start=>$start,-stop=>$stop) unless $whole;

  if (@_) {
    if ($_[0] =~ /^-/) {
      push @args,@_;
    } else {
      my @types = @_;
      push @args,-types=>\@types;
    }
  }
  push @args,-parent=>$self;
  @args;
}

# wrapper for lower-level types() call.
sub types {
  my $self = shift;
  my ($ref,$class,$start,$stop,$strand) = @{$self}{qw(sourceseq class start stop strand)};
  ($start,$stop) = ($stop,$start) if $strand eq '-';
  $self->factory->types(-ref  => $ref,
			-class => $class,
			-start=> $start,
			-stop => $stop,
			@_);
}

sub abs2rel {
  my $self = shift;
  my @result;
  return unless defined $_[0];

  if ($self->absolute) {
    @result = @_;
  } else {
    my ($refstart,$refstrand) = @{$self}{qw(refstart refstrand)};
    @result = $refstrand eq '+' ? map { $_ - $refstart + 1 } @_
                                : map { $refstart - $_ + 1 } @_;
  }
  # if called with a single argument, caller will expect a single scalar reply
  # not the size of the returned array!
  return $result[0] if @result == 1 and !wantarray;
  @result;
}
sub rel2abs {
  my $self = shift;
  my @result;

  if ($self->absolute) {
    @result = @_;
  } else {
    my ($refstart,$refstrand) = @{$self}{qw(refstart refstrand)};
    @result = $refstrand eq '+' ? map { $_ + $refstart + 1 } @_ 
                                : map { $refstart - $_ + 1 } @_;
  }
  # if called with a single argument, caller will expect a single scalar reply
  # not the size of the returned array!
  return $result[0] if @result == 1 and !wantarray;
  @result;
}

sub error {
  my $self = shift;
  my $g = $self->{error};
  $self->{error} = shift if @_;
  $g;
}

sub subseq {
  my $self = shift;
  my $obj  = $self->SUPER::subseq(@_);
  bless $obj,__PACKAGE__;    # always bless into the generic RelSegment package
}

sub make_feature {
  my $self = shift;
  my $group_list = shift;
  my ($start,$stop,$method,$source,
      $score,$strand,$phase,
      $class,$name,
      $tstart,$tstop) = @_;

  # this is actually just a call back to the factory
  my $group = $self->toObject($class,$name,$tstart,$tstop)
    if defined $class && defined $name;

  my $f = Bio::DB::GFF::Feature->new_feature($self,$start,$stop,
					     $method,$source,
					     $score,$strand,$phase,
					     $group);

  if ($group and $class ne 'Note') {
    my $id = $group->id;
    $group_list->{$id} ||= Bio::DB::GFF::Feature->new_feature($self,undef,undef,
							      $class,$name,
							      undef,undef,undef,
							      $group);
    $group_list->{$id}->add_subfeature($f);
  } else {
    $group_list->{$f->id} = $f;
  }
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Ace::Sequence::Mysql - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Ace::Sequence::Mysql;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Ace::Sequence::Mysql, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
