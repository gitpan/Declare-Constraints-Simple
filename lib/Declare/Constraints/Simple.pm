=head1 NAME

Declare::Constraints::Simple - Declarative Validation of Data Structures

=cut

package Declare::Constraints::Simple;
use warnings;
use strict;

use Carp::Clan qw(^Declare::Constraints::Simple);
use Class::Inspector;

use aliased 'Declare::Constraints::Simple::Library';

our $VERSION = 0.01;

=head1 SYNOPSIS

  use Declare::Constraints::Simple-All;

  my $profile = IsHashRef(
                    -keys   => HasLength,
                    -values => IsArrayRef( IsObject ));

  my $result1 = $profile->(undef);
  print $result1->message, "\n";    # 'Not a HashRef'

  my $result2 = $profile->({foo => [23]});

  print $result2->message, "\n";    # 'Not an Object'

  print $result2->path, "\n";       
                    # 'IsHashRef[val foo].IsArrayRef[0].IsObject'

=head1 DESCRIPTION

The main purpose of this module is to provide an easy way to build a profile
to validate a data structure. It does this by providing you with a set of
declarative keywords exported into your namespace.

=head1 USAGE

  use Declare::Constraints::Simple-All;

The above command imports all constraint generators in the library into the
current namespace. If you want only a selection, use C<only>:

  use Declare::Constraints::Simple Only => qw(IsInt Matches And);

You can find all constraints (and constraint-like generators, like operators.
In fact, C<And> above is an operator. They're both implemented equally, so 
the distinction is a merely philosophical one) documented in the
L<Declare::Constraints::Simple::Library> pod. In that document you will also
find the exact parameters for their usage, so this here is just a brief Intro
and not a coverage of all possibilities.

You can use these constraints by building a tree that describes what data
structure you expect. Every constraint can be used as sub-constraint, as
parent, if it accepts other constraints, or stand-alone. If you'd just say

  my $check = IsInt;
  print "yes!\n" if $check->(23);

it will work too. This also allows predefining tree segments, and nesting them:

  my $id_to_objects = IsArrayRef(IsObject);

Here C<$id_to_objects> would give it's OK on an array reference containing a
list of objects. But what if we now decide that we actually want a hashref
containing two lists of objects? Behold:

  my $object_lists = IsHashRef( HasAllKeys( qw(good bad) ),
                                OnHashKeys( good => $id_to_objects,
                                            bad  => $id_to_objects ));

As you can see, constraints like C<IsArrayRef> and C<IsHashRef> allow you to
apply constraints to their keys and values. With this, you can step down in the
data structure.

Constraints return just code references that can be applied to one value (and
only one value) like this:

  my $result = $object_lists->($value);

After this call C<$result> contains a L<Declare::Constraints::Simple::Result>
object. The first think one wants to know is if the validation succeeded:

  if ($result->is_valid) { ... }

This is pretty straight forward. To shorten things the result object also 
L<overload>s it's C<bool>ean context. This means you can alternatively just
say

  if ($result) { ... }

However, if the result indicates a invalid data structure, we have a few
options to find out what went wrong. There's a human parsable message in
the C<message> accessor. You can override these by forcing it to a message
in a subtree with the C<Message> declaration. The C<stack> contains the
name of the chain of constraints up to the point of failure. 

=head1 METHODS

=head2 import($flag, @args)

Exports the constraints to the calling namespace.

=cut

sub import {
    my ($class, $flag, @args) = @_;
    return unless $flag;

    my $handle_map = $class->_build_handle_map;
    
    if ($flag =~ /^-?all$/i) {
        $class->_export_all(scalar(caller), $handle_map);
    }
    elsif ($flag =~ /^-?only$/i) {
        $class->_export_these(scalar(caller), $handle_map, @args);
    }

    1;
}

=head2 _build_handle_map()

Internal method to build constraint-to-class mappings.

=cut

sub _build_handle_map {
    my ($class) = @_;

    my (%seen, %handle_map, @walk, %walked);
    @walk = do {
        no strict 'refs'; 
        (($class eq __PACKAGE__ ? Library : $class), 
         @{$class . '::ISA'}) 
    };

    while (my $w = shift @walk) {
        $walked{$w} = 1;

        if (Class::Inspector->function_exists(
                $w, 'fetch_constraint_declarations')) {
            my @decl = $w->fetch_constraint_declarations;
            for my $d (@decl) {
                next if exists $seen{$d};
                $seen{$d} = 1;
                $handle_map{$d} = $w;
            }
        }

        push @walk,
            grep { not exists $walked{$_} }
              do { no strict 'refs' ; @{$w . '::ISA'} };
    }

    return \%handle_map;
}

=head2 _export_all($target, $handle_map)

Internal method. Exports all handles in C<$handle_map> into the C<$target> 
namespace.

=cut

sub _export_all {
    my ($class, $target, $handle_map) = @_;
    return $class->_export_these($target, $handle_map, keys %$handle_map);
}

=head2 _export_these($target, $handle_map, @constraints)

Internal method. Exports all C<@constraints> from C<$handle_map> into the
C<$target> namespace.

=cut

sub _export_these {
    my ($class, $target, $handle_map, @decl) = @_;
    
    for my $d (@decl) {
        my $gen = $handle_map->{$d}->fetch_constraint_generator($d);

        croak sprintf 
            'Constraint Generator for $s in %s did not return a closure',
            $d, $handle_map->{$d}
            unless ref($gen) eq 'CODE';

        {   no strict 'refs';
            *{$target . '::' . $d} = $gen;
        }
    }
}

=head1 SEE ALSO

L<Declare::Constraints::Simple::Library>, 
L<Declare::Constraints::Simple::Result>

=head1 REQUIRES

L<Carp::Clan>, L<aliased>, L<Class::Inspector>, L<Scalar::Util>,
L<overload> and L<Test::More> (for build).

=head1 TODO

=over

=item *

More tests of course!

=item *

An C<OnArrayElements> constraint. Like C<OnHashKeys> but for array
references.

=item *

Examples.

=item *

A list of questions that might come up, together with their answers.

=item *

Inheritance. Developers should be able to make their own libraries
and define own constraints.

=item *

Dependencies. We need keywords like C<As($name, $constraint> and 
C<IfValid($name, $constraint)>.

=item *

Scoping. It would be nice to have a C<Let> constraint that introduces
variables. These could be set under their scope with a C<SetValue>
constraint and retrieved with C<GetValue>. This would open the 
possibility of comparison operators.

=item *

???

=item *

Profit.

=back

=head1 AUTHOR

Robert 'phaylon' Sedlacek C<E<lt>phaylon@dunkelheit.atE<gt>>

=head1 LICENSE AND COPYRIGHT

This module is free software, you can redistribute it and/or modify it 
under the same terms as perl itself.

=cut

1;
