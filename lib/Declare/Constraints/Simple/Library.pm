=head1 NAME

Declare::Constraints::Simple::Library - Constraint Library

=cut

package Declare::Constraints::Simple::Library;
use warnings;
use strict;

use Carp::Clan qw/^Declare::Constraints::Simple/;
use Scalar::Util qw(blessed looks_like_number);
use Class::Inspector;

use aliased 'Declare::Constraints::Simple::Result';

=head1 DESCRIPTION

This is the constraint library for the L<Declare::Constraints::Simple>
module.

=cut

our $FAIL_MESSAGE = 'Validation Error';
our $FAIL_INFO;

sub _result {
    my ($result, $msg) = @_;
    my $result_obj = Result->new;
    $result_obj->set_valid($result);
    $result_obj->set_message($FAIL_MESSAGE || $msg)
        unless $result_obj->is_valid;
    return $result_obj;
}

sub _false { _result(0, @_) }
sub _true  { _result(1, @_) }

sub _info  { $FAIL_INFO = shift }

my %generators = (
    Message => sub {
        my ($msg, $c) = @_;
        return sub {
            local $FAIL_MESSAGE = $msg;
            return $c->($_[0]);
        };
    },
    IsRefType => sub {
        my (@types) = @_;
        return sub { 
            return _false('Undefined Value') unless defined $_[0];
            my @match = grep { ref($_[0]) eq $_ } @types;
            return scalar(@match) ? _true : _false('No matching RefType');
        };
    },
    HasMethods => sub {
        my (@methods) = @_;
        return sub { 
            return _false('Undefined Value') unless defined $_[0];
            return _false('Not a Class or Object') unless blessed($_[0])
                or Class::Inspector->loaded($_[0]);
            for (@methods) { 
                unless ($_[0]->can($_)) {
                    _info($_);
                    return _false("Method $_ not implemented");
                }
            }
            return _true;
        };
    },
    IsA => sub {
        my (@classes) = @_;
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            for (@classes) { return _true if eval { $_[0]->isa($_) } }
            return _false('No matching Class');
        };
    },
    IsArrayRef => sub {
        my @vc = @_;
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            return _false('Not an ArrayRef') unless ref($_[0]) eq 'ARRAY';
            for (0 .. $#{$_[0]}) { 
                my $result = _apply_checks($_[0][$_], \@vc, $_);
                return $result unless $result->is_valid;
            }
            return _true;
        };
    },
    HasArraySize => sub {
        my ($min, $max) = @_;
        $min = 1 unless defined $min;
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            return _false('Not an ArrayRef') unless ref($_[0]) eq 'ARRAY';
            return _false("Less than $min Array elements")
                unless scalar(@{$_[0]}) >= $min;
            return _true 
                unless $max;
            return _false("More than $max Array elements")
                unless scalar(@{$_[0]}) <= $max;
            return _true;
        };
    },
    IsHashRef => sub {
        my %def = @_;
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            return _false('Not a HashRef') unless ref($_[0]) eq 'HASH';
            if (my $c = $def{'-values'}) {
                for (keys %{$_[0]}) {
                    my $r = _apply_checks($_[0]{$_}, _listify($c), "val $_");
                    return $r unless $r->is_valid;
                }
            }
            if (my $c = $def{'-keys'}) {
                for (keys %{$_[0]}) {
                    my $r = _apply_checks($_, _listify($c), "key $_");
                    return $r unless $r->is_valid;
                }
            }
            return _true;
        };
    },
    IsCodeRef => sub {
        return sub { 
            return _false('Undefined Value') unless defined $_[0];
            return _result((ref($_[0]) eq 'CODE'), 'Not a CodeRef');
        };
    },
    IsScalarRef => sub {
        my @vc = @_;
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            return _false('Not a ScalarRef') unless ref($_[0]) eq 'SCALAR';
            return _true unless @vc;
            my $result = _apply_checks(${$_[0]}, \@vc);
            return $result unless $result->is_valid;
            return _true;
        };
    },
    IsClass => sub {
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            return _result(Class::Inspector->loaded($_[0]), 'Not a loaded Class');
        };
    },
    IsNumber => sub {
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            return _result(looks_like_number($_[0]), 'Does not look like Number');
        };
    },
    IsInt => sub {
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            return _result(scalar($_[0] =~ /^-?\d+$/), 'Not an Integer');
        };
    },
    Matches => sub {
        my @rx = @_;
        croak 'Matches needs at least one Regexp as argument'
            unless @rx;
        for (@rx) {
            croak 'Matches only takes Regexps as arguments'
                unless ref($_) eq 'Regexp';
        }
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            for (@rx) {
                return _true if $_[0] =~ /$_/;
            }
            return _false('Regex does not match');
        };
    },
    IsDefined => sub {
        return sub { return _result((defined($_[0]) ? 1 : 0), 'Undefined Value') };
    },
    HasLength => sub {
        my ($min, $max) = @_;
        $min = 1 unless defined $min;
        $max = 0 unless defined $max;
        return sub {
            my ($val) = @_;
            return _false('Undefined Value') unless defined $val;
            return _false('Value too short') unless $min <= length($val);
            return _true unless $max;
            return _result(((length($val) <= $max) ? 1 : 0), 'Value too long');
        };
    },
    IsOneOf => sub {
        my @vals = @_;
        return sub {
            for (@vals) {
                unless (defined $_) {
                    return _true unless defined $_[0];
                    next;
                }
                next unless defined $_[0];
                return _true if $_[0] eq $_;
            }
            return _false('No Value matches');
        };
    },
    IsTrue => sub {
        return sub { $_[0] ? _true : _false('Value evaluates to False') };
    },
    Not => sub {
        my @c = @_;
        return sub {
            for (@c) {
                croak 'The Not constraint only accepts closures as arguments'
                    unless ref($_) eq 'CODE';
                my $r = $_->($_[0]);
                next unless $r->is_valid;
                return _false('Subchecks returned true');
            }
            return _true;
        };
    },
    IsRegex => sub {
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            return _result((ref($_[0]) eq 'Regexp'), 'Not a Regular Expression');
        };
    },
    HasAllKeys => sub {
        my @vk = @_;
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            return _false('Not a HashRef') unless ref($_[0]) eq 'HASH';
            for (@vk) {
                unless (exists $_[0]{$_}) {
                    _info($_);
                    return _false("No '$_' key present");
                }
            }
            return _true;
        };
    },
    OnHashKeys => sub {
        my %def = @_;
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            return _false('Not a HashRef') unless ref($_[0]) eq 'HASH';
            for (keys %def) {
                my @vc = @{_listify($def{$_})};
                next unless exists $_[0]{$_};
                my $r = _apply_checks($_[0]{$_}, \@vc, $_);
                return $r unless $r->is_valid;
            }
            return _true;
        };
    },
    IsObject => sub {
        return sub {
            return _false('Undefined Value') unless defined $_[0];
            return _result(blessed($_[0]), 'Not an Object');
        };
    },
    And => sub {
        my @vc = @_;
        return sub {
            for (@vc) {
                my $r = $_->($_[0]);
                return $r unless $r->is_valid;
            }
            return _true;
        };
    },
    Or => sub {
        my @vc = @_;
        return sub {
            my $last_r;
            for (@vc) {
                my $r = $_->($_[0]);
                return _true if $r->is_valid;
                $last_r = $r;
            }
            return $last_r if $last_r and not $last_r->is_valid;
            return _false;
        };
    },
    XOr => sub {
        my @vc = @_;
        return sub {
            my $m = 0;
            for (@vc) {
                my $r = $_->($_[0]);
                $m++ if $r->is_valid;
            }
            return _result(($m == 1), sprintf 'Got %d true returns', $m);
        };
    },
);

sub _listify {
    my ($value) = @_;
    return (ref($value) eq 'ARRAY' ? $value : [$value]);
}

sub _apply_checks {
    my ($value, $checks, $info) = @_;
    $checks ||= [];
    $FAIL_INFO = $info if $info;
    for (@$checks) {
        my $result = $_->($value);
        return $result unless $result->is_valid;
    }
    return _true;
}

sub fetch_constraint_declarations {
    return keys %generators;
}

sub fetch_constraint_generator {
    my ($class, $constraint) = @_;
    croak "Unable to find generator for $constraint"
        unless exists $generators{$constraint};
    return $class->prepare_generator(
        $constraint, $generators{$constraint});
}

sub prepare_generator {
    my ($class, $constraint, $generator) = @_;
    return sub {
        my (@g_args) = @_;
        my $closure = $generator->(@g_args);

        return sub {
            my (@c_args) = @_;

            local $FAIL_INFO;
            my $result = $closure->(@c_args);
            my $info = ($FAIL_INFO ? "[$FAIL_INFO]" : '');
            $result->add_to_stack($constraint . $info) unless $result;

            return $result;
        };
    };
}

=head1 SCALAR CONSTRAINTS

=head2 Matches(@regex)

  my $c = Matches(qr/foo/, qr/bar/);

If one of the parameters matches the expression, this is true.

=head2 IsDefined()

True if the value is defined

=head2 HasLength([$min, [$max]])

Is true if the value has a length above C<$min> (which defaults to 1> and,
if supplied, under the value of C<$max>. A simple.

  my $c = HasLength->($value);

Checks if the value has a length of at least 1.

=head2 IsOneOf(@values)

True if one of the C<@values> equals the passed value. C<undef> values
work with this too, so

  my $c = IsOneOf(1, 2, undef);

will return true on an undefined value.

=head2 IsTrue()

True if the value evulates to true.

=head1 NUMERICAL CONSTRAINTS

=head2 IsNumber()

True if the value is a number according to L<Scalar::Util>s 
C<looks_like_number>. 

=head2 IsInt()

True if the value is an integer.

=head1 OO CONSTRAINTS

=head2 IsA(@classes)

Is true if the passed object or class is a subclass of one
of the classes mentioned in C<@classes>.

=head2 IsClass()

Valid if value is a loaded class.

=head2 HasMethods(@methods)

Returns true if the value is an object or class that C<can>
all the specified C<@methods>.

The stack or path part of C<HasMethods> looks like C<HasMethods[$method]>
where C<$method> is the first found missing method.

=head2 IsObject()

True if the value is blessed.

=head1 REFERENCIAL CONSTRAINTS

=head2 IsRefType(@types)

Valid if the value is a reference of a kind in C<@types>.

=head2 IsScalarRef($constraint)

This is true if the value is a scalar reference. A possible constraint
for the scalar references target value can be passed. E.g.

  IsScalarRef(IsInt)

=head2 IsArrayRef($constraint)

The value is valid if the value is an array reference. The contents of
the array can be validated by passing an other C<$constraint> as 
argument.

The stack or path part of C<IsArrayRef> is C<IsArrayRef[$index]> where
C<$index> is the index of the failing element.

=head2 IsHashRef(-keys => $constraint, -values => $constraint)

True if the value is a hash reference. It can also take two named
parameters: C<-keys> can pass a constraint to check the hashes keys,
C<-values> does the same for its values.

The stack or path part of C<IsHashRef> looks like C<IsHashRef[$type $key]>
where C<$type> is either C<val> or C<key> depending on what was validated,
and C<$key> being the key that didn't pass validation.

=head2 IsCodeRef()

Code references have to be valid to pass this constraint.

=head2 IsRegex()

True if the value is a regular expression built with C<qr>. B<Note>
however, that a simple string that could be used like C</$rx/> will
not pass this constraint. You can combine multiple constraints with
L<And(@constraints)> though.

=head1 ARRAY CONSTRAINTS

These deal with array references.

=head2 HasArraySize([$min, [$max]])

With C<$min> defaulting to 1. So a specification of

  my $profile = HasArraySize;

Checks for at least one value. To force an exact size of the array,
specify the same values for both.

  my $profile = HasArraySize(3, 3);

=head1 HASH CONSTRAINTS

These are the constraints that are only for hash reference
validation.

=head2 HasAllKeys(@keys)

The value has to be a hashref, and contain all keys listed in 
C<@keys> to pass this constraint.

The stack or path part of C<HasAllKeys> is C<HasAllKeys[$key]> where
C<$key> is the missing key.

=head2 OnHashKeys(key => $constraint, key => $constraint, ...)

This allows you to pass a constraint for each specific key in
a hash reference. If a specified key is not in the validated
hash reference, the validation for this key is not done. To make
a key a requirement, use L<HasAllKeys(@keys)> above in combination
with this, e.g. like:

  And( HasAllKeys( qw(foo bar baz) )
       OnHashKeys( foo => IsInt,
                   bar => Matches(qr/bar/),
                   baz => IsArrayRef( HasLength )));

Also, as you might see, you don't have to check for C<IsHashRef>
validity here. The hash constraints are already doing that by
themselves.

The stack or path part of C<OnHashKeys> looks like C<OnHashKeys[$key]>
where C<$key> is the key of the failing value.

=head1 OPERATORS

Operators can be used in any place a constraint can be used, as
their implementations are similar.

=head2 And(@constraints)

Is true if all passed C<@constraints> are true on the value.

=head2 Or(@constraints)

Is true if at least one of the passed C<@contraints> is true.

=head2 XOr(@constraints)

Valid only if a single one of the passed C<@constraints> is valid.

=head2 Not($constraint)

This is valid if the passed C<$constraint> is false. The main purpose
of this operator is to allow the easy reversion of a constraint's 
trueness.

=head1 OTHER CONSTRAINT LIKE GENERATORS

=head2 Message($message, $constraint)

Overrides the C<message> set on the result object for failures in
C<$constraint>.

=head1 METHODS AND SUBROUTINES

=head2 _result($bool, $message)

Internal subroutine. Creates a new result object. Validity is determined by
the C<$bool> argument. The C<$message> is the message to be set if the
validation failed.

=head2 _true()

Internal subroutine. Returns a true result.

=head2 _false($message)

Internal subroutine. Creates a new false result object with C<$message>.

=head2 _info($value)

Internal subroutine. Sets the info value that is used to determine current
hash keys, array indexes and the like.

=head2 _listify($value)

Internal helper to force C<$value> into an array reference, if it isn't
already one.

=head2 _apply_checks($value, $checks, $info)

Internal subroutine. This runs the C<$checks> on C<$value> and uses C<$info>
to set the current info value on failure.

=head2 fetch_constraint_declarations()

Class method. This returns all constraints provided by this class.

=head2 fetch_constraint_generator($constraint_name)

Class method. Returns the constraint generator for this class with the name
passed as C<$constraint_name>.

=head2 prepare_generator($constraint, $generator)

Class method. This prepares a constraint generator with the collapsing
facilities needed for the stack and info data.

=head1 SEE ALSO

L<Declare::Constraints::Simple>

=head1 AUTHOR

Robert 'phaylon' Sedlacek C<E<lt>phaylon@dunkelheit.atE<gt>>

=head1 LICENSE AND COPYRIGHT

This module is free software, you can redistribute it and/or modify it 
under the same terms as perl itself.

=cut

1;

