=head1 NAME

Declare::Constraints::Simple::Library::Array - Array Constraints

=cut

package Declare::Constraints::Simple::Library::Array;
use warnings;
use strict;

use Declare::Constraints::Simple-Library;

=head1 SYNOPSIS

  # accept a list of pairs
  my $pairs_validation = IsArrayRef( HasArraySize(2,2) );

=head1 DESCRIPTION

This module contains all constraints that can be applied to array
references.

=head1 CONSTRAINTS

=head2 HasArraySize([$min, [$max]])

With C<$min> defaulting to 1. So a specification of

  my $profile = HasArraySize;

checks for at least one value. To force an exact size of the array,
specify the same values for both:

  my $profile = HasArraySize(3, 3);

=cut

constraint 'HasArraySize',
    sub {
        my ($min, $max) = @_;
        $min = 1 unless defined $min;
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            return _false('Not an ArrayRef') 
                unless ref($_[0]) eq 'ARRAY';
            return _false("Less than $min Array elements")
                unless scalar(@{$_[0]}) >= $min;
            return _true 
                unless $max;
            return _false("More than $max Array elements")
                unless scalar(@{$_[0]}) <= $max;
            return _true;
        };
    };

=head1 SEE ALSO

L<Declare::Constraints::Simple>, L<Declare::Constraints::Simple::Library>

=head1 AUTHOR

Robert 'phaylon' Sedlacek C<E<lt>phaylon@dunkelheit.atE<gt>>

=head1 LICENSE AND COPYRIGHT

This module is free software, you can redistribute it and/or modify it 
under the same terms as perl itself.

=cut

1;
