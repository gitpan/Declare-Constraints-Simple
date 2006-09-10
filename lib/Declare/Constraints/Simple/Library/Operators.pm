=head1 NAME

Declare::Constraints::Simple::Library::Operators - Operators

=cut

package Declare::Constraints::Simple::Library::Operators;
use warnings;
use strict;

use Declare::Constraints::Simple-Library;

use Carp::Clan qw(^Declare::Constraints::Simple);

=head1 SYNOPSIS

  # all hast to be valid
  my $and_constraint = And( IsInt,
                            Matches(qr/0$/) );

  # at least one has to be valid
  my $or_constraint = Or( IsInt, HasLength );

  # only one can be valid
  my $xor_constraint = XOr( IsClass, IsObject );

  # reverse validity
  my $not_an_integer = Not( IsInt );

=head1 DESCRIPTION

This module contains the frameworks operators. These constraint like
elements act on the validity of passed constraints.

=head1 OPERATORS

=head2 And(@constraints)

Is true if all passed C<@constraints> are true on the value. Returns
the result of the first failing constraint.

=cut

constraint 'And',
    sub {
        my @vc = @_;
        return sub {
            for (@vc) {
                my $r = $_->($_[0]);
                return $r unless $r->is_valid;
            }
            return _true;
        };
    };

=head2 Or(@constraints)

Is true if at least one of the passed C<@contraints> is true. Returns the
last failing constraint's result if false.

=cut

constraint 'Or',
    sub {
        my @vc = @_;
        return sub {
            my $last_r;
            for (0 .. $#vc) {
                my $v = $vc[$_];
                my $r = $v->($_[0]);
                return _true if $r->is_valid;
                return $r if $_ == $#vc;
            }
            return _false('No constraints');
        };
    };

=head2 XOr(@constraints)

Valid only if a single one of the passed C<@constraints> is valid. Returns
the last failing constraint's result if false.

=cut

constraint 'XOr',
    sub {
        my @vc = @_;
        return sub {
            my $m = 0;
            for (@vc) {
                my $r = $_->($_[0]);
                $m++ if $r->is_valid;
            }
            return _result(($m == 1), sprintf 'Got %d true returns', $m);
        };
    };

=head2 Not($constraint)

This is valid if the passed C<$constraint> is false. The main purpose
of this operator is to allow the easy reversion of a constraint's 
trueness.

=cut

constraint 'Not',
    sub {
        my ($c) = @_;
        croak '\'Not\' only accepts only a constraint as argument'
            if defined $c and not ref($c) eq 'CODE';
        return sub {
            return _true unless $c;
            my $r = $c->($_[0]);
            return _false('Constraint returned true') if $r->is_valid;
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
