
#
# BioPerl module for Bio::Pfam::Annotation::Comment
#
# Cared for by James Gilbert <jgrg@sanger.ac.uk>
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Species - Generic species object

=head1 SYNOPSIS

    $species = Bio::Species->new(); # Can also pass classification
                                    # array to new as below
                                    
    $species->classification(qw( sapiens Homo Hominidae
                                 Catarrhini Primates Eutheria
                                 Mammalia Vertebrata Chordata
                                 Metazoa Eukaryota ));
    
    $genus = $species->genus();
    
    $bi = $species->binomial();     # $bi is now "Homo sapiens"
    
    # For storing common name
    $species->common_name("human");

=head1 DESCRIPTION

Provides a very simple object for storing phylogenetic
information.  The classification is stored in an array,
which is a list of nodes in a phylogenetic tree.  Access to
getting and setting species and genus is provided, but not
to any of the other node types (eg: "phlum", "class",
"order", "family").  There's plenty of scope for making the
model more sophisticated, if this is ever needed.

A mehod is also provided for storing a common name of the
species.

=head1 CONTACT

James Gilbert email B<jgrg@sanger.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


#' Let the code begin...


package Bio::Species;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::Object

use Bio::Root::Object;


@ISA = qw(Bio::Root::Object);
# new() is inherited from Bio::Root::Object

# _initialize is where the heavy stuff will happen when new is called

sub _initialize {
  my($self,@args) = @_;

  my $make = $self->SUPER::_initialize;

  $self->{'classification'} = [];
  $self->{'common_name'} = undef;
  if (@args) {
    $self->classification(@args);
  }
  return $make; # success - we hope!
}

=head2 classification

 Title   : classification
 Usage   : $self->classification(@class_array);
           @classification = $self->classification();
 Function: Fills or returns the classifcation list in
           the object.  The array provided must be in
           the order SPECIES, GENUS ---> KINGDOM.
           The first element of the array, the species,
           must be in lower case, and the rest in title
           case.  Only species must be present.
 Example : $self->classification(qw( sapiens Homo Hominidae
           Catarrhini Primates Eutheria Mammalia Vertebrata
           Chordata Metazoa Eukaryota));
 Returns : Classification array
 Args    : Classification array

=cut



sub classification {
    my $self = shift;
    if (@_) {
        my @classification = @_;
        
        # Check the names supplied in the classification string
        {
            # Species should be in lower case
            my $species = $classification[0];
            $self->validate_species_name( $species );

            # All other names must be in title case
            for (my $i = 1; $i < @classification; $i++) {
                $self->validate_name( $classification[$i] );
            }
        }
        
        # Store classification
        $self->{'classification'} = [ @classification ];
    } else {
        return @{$self->{'classification'}};
    }
}

=head2 

 Title   : common_name
 Usage   : $self->common_name( $common_name );
           $common_name = $self->common_name();
 Function: Get or set the commonn name of the species
 Example : $self->common_name('human')
 Returns : The common name in a string
 Args    : String, which is the common name

=cut

sub common_name {
    my($self, $name) = @_;
    
    if ($name) {
        $self->{'common_name'} = $name;
    } else {
        return $self->{'common_name'} 
    }
}

=head2 species

 Title   : species
 Usage   : $self->species( $species );
           $species = $self->species();
 Function: Get or set the scientific species name.  The species
           name must be in lower case.
 Example : $self->species( 'sapiens' );
 Returns : Scientific species name as string
 Args    : Scientific species name as string

=cut


sub species {
    my($self, $species) = @_;
    
    if ($species) {
        $self->validate_species_name( $species );
        $self->{'classification'}[0] = $species;
    } else {
        return $self->{'classification'}[0];
    }
}

=head2 genus

 Title   : genus
 Usage   : $self->genus( $genus );
           $genus = $self->genus();
 Function: Get or set the scientific genus name.  The genus
           must be in title case.
 Example : $self->genus( 'Homo' );
 Returns : Scientific genus name as string
 Args    : Scientific genus name as string

=cut


sub genus {
    my($self, $genus) = @_;
    
    if ($genus) {
        $self->validate_name( $genus );
        $self->{'classification'}[1] = $genus;
    } else {
        return $self->{'classification'}[1];
    }

}

=head2 binomial

 Title   : binomial
 Usage   : $binomial = $self->binomial();
 Function: Returns a string "Genus species"
 Args    : None

=cut


sub binomial {
    my( $self ) = @_;
    
    my( $species, $genus ) = $self->classification();
    return "$genus $species";
}

sub validate_species_name {
    my( $self, $string ) = @_;
    
    $string =~ /^[a-z]+$/ or
        $self->throw("Invalid species name '$string' (Wrong case?)");
}

sub validate_name {
    my( $self, $string ) = @_;
    
    return $string =~ /^[A-Z][a-z]+$/ or
        $self->throw("Invalid name '$string' (Wrong case?)");
}


1;

__END__
