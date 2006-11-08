package Class::Accessor::Grouped;
use strict;
use warnings;
use Carp;
use Class::ISA;
use Scalar::Util qw/blessed reftype/;
use vars qw($VERSION);

$VERSION = '0.03';

=head1 NAME

Class::Accessor::Grouped - Lets you build groups of accessors

=head1 SYNOPSIS

=head1 DESCRIPTION

This class lets you build groups of accessors that will call different
getters and setters.

=head1 METHODS

=head2 mk_group_accessors

=over 4

=item Arguments: $group, @fieldspec

Returns: none

=back

Creates a set of accessors in a given group.

$group is the name of the accessor group for the generated accessors; they
will call get_$group($field) on get and set_$group($field, $value) on set.

@fieldspec is a list of field/accessor names; if a fieldspec is a scalar
this is used as both field and accessor name, if a listref it is expected to
be of the form [ $accessor, $field ].

=cut

sub mk_group_accessors {
  my ($self, $group, @fields) = @_;

  $self->_mk_group_accessors('make_group_accessor', $group, @fields);
  return;
}


{
    no strict 'refs';
    no warnings 'redefine';

    sub _mk_group_accessors {
        my($self, $maker, $group, @fields) = @_;
        my $class = ref $self || $self;

        # So we don't have to do lots of lookups inside the loop.
        $maker = $self->can($maker) unless ref $maker;

        foreach my $field (@fields) {
            if( $field eq 'DESTROY' ) {
                carp("Having a data accessor named DESTROY  in ".
                             "'$class' is unwise.");
            }

            my $name = $field;

            ($name, $field) = @$field if ref $field;

            my $accessor = $self->$maker($group, $field);
            my $alias = "_${name}_accessor";

            #warn "$class $group $field $alias";

            *{$class."\:\:$name"}  = $accessor;
              #unless defined &{$class."\:\:$field"}

            *{$class."\:\:$alias"}  = $accessor;
              #unless defined &{$class."\:\:$alias"}
        }
    }
}

=head2 mk_group_ro_accessors

=over 4

=item Arguments: $group, @fieldspec

Returns: none

=back

Creates a set of read only accessors in a given group. Identical to
<L:/mk_group_accessors> but accessors will throw an error if passed a value
rather than setting the value.

=cut

sub mk_group_ro_accessors {
    my($self, $group, @fields) = @_;

    $self->_mk_group_accessors('make_group_ro_accessor', $group, @fields);
}

=head2 mk_group_wo_accessors

=over 4

=item Arguments: $group, @fieldspec

Returns: none

=back

Creates a set of write only accessors in a given group. Identical to
<L:/mk_group_accessors> but accessors will throw an error if not passed a
value rather than getting the value.

=cut

sub mk_group_wo_accessors {
    my($self, $group, @fields) = @_;

    $self->_mk_group_accessors('make_group_wo_accessor', $group, @fields);
}

=head2 make_group_accessor

=over 4

=item Arguments: $group, $field

Returns: $sub (\CODE)

=back

Returns a single accessor in a given group; called by mk_group_accessors
for each entry in @fieldspec.

=cut

sub make_group_accessor {
    my ($class, $group, $field) = @_;

    my $set = "set_$group";
    my $get = "get_$group";

    # Build a closure around $field.
    return sub {
        my $self = shift;

        if(@_) {
            return $self->$set($field, @_);
        }
        else {
            return $self->$get($field);
        }
    };
}

=head2 make_group_ro_accessor

=over 4

=item Arguments: $group, $field

Returns: $sub (\CODE)

=back

Returns a single read-only accessor in a given group; called by
mk_group_ro_accessors for each entry in @fieldspec.

=cut

sub make_group_ro_accessor {
    my($class, $group, $field) = @_;

    my $get = "get_$group";

    return sub {
        my $self = shift;

        if(@_) {
            my $caller = caller;
            croak("'$caller' cannot alter the value of '$field' on ".
                        "objects of class '$class'");
        }
        else {
            return $self->$get($field);
        }
    };
}

=head2 make_group_wo_accessor

=over 4

=item Arguments: $group, $field

Returns: $sub (\CODE)

=back

Returns a single write-only accessor in a given group; called by
mk_group_wo_accessors for each entry in @fieldspec.

=cut

sub make_group_wo_accessor {
    my($class, $group, $field) = @_;

    my $set = "set_$group";

    return sub {
        my $self = shift;

        unless (@_) {
            my $caller = caller;
            croak("'$caller' cannot access the value of '$field' on ".
                        "objects of class '$class'");
        }
        else {
            return $self->$set($field, @_);
        }
    };
}

=head2 get_simple

=over 4

=item Arguments: $field

Returns: $value

=back

Simple getter for hash-based objects which returns the value for the field
name passed as an argument.

=cut

sub get_simple {
  my ($self, $get) = @_;
  return $self->{$get};
}

=head2 set_simple

=over 4

=item Arguments: $field, $new_value

Returns: $new_value

=back

Simple setter for hash-based objects which sets and then returns the value
for the field name passed as an argument.

=cut

sub set_simple {
  my ($self, $set, $val) = @_;
  return $self->{$set} = $val;
}


=head2 get_inherited

=over 4

=item Arguments: $field

Returns: $value

=back

Simple getter for Classes and hash-based objects which returns the value for the field name passed as
an argument. This behaves much like L<Class::Data::Accessor> where the field can be set in a
base class, inherited and changed in subclasses, and inherited and changed for object instances.

=cut

sub get_inherited {
    my ($self, $get) = @_;
    my $class;

    if (blessed $self) {
        my $reftype = reftype $self;
        $class = ref $self;

        if ($reftype eq 'HASH' && exists $self->{$get}) {
            return $self->{$get};
        } elsif ($reftype ne 'HASH') {
            croak('Cannot get inherited value on an object instance that is not hash-based');
        };
    } else {
        $class = $self;
    };

    no strict 'refs';
    return ${$class.'::__cag_'.$get} if defined(${$class.'::__cag_'.$get});

    if (!@{$class.'::__cag_supers'}) {
        @{$class.'::__cag_supers'} = $self->get_super_paths;
    };

    foreach (@{$class.'::__cag_supers'}) {
        return ${$_.'::__cag_'.$get} if defined(${$_.'::__cag_'.$get});
    };

    return;
}

=head2 set_inherited

=over 4

=item Arguments: $field, $new_value

Returns: $new_value

=back

Simple setter for Classes and hash-based objects which sets and then returns the value
for the field name passed as an argument. When called on a hash-based object it will set the appropriate
hash key value. When called on a class, it will set a class level variable.

B<Note:>: This method will die if you try to set an object variable on a non hash-based object.

=cut

sub set_inherited {
    my ($self, $set, $val) = @_;

    if (blessed $self) {
        if (reftype($self) eq 'HASH') {
            return $self->{$set} = $val;
        } else {
            croak('Cannot set inherited value on an object instance that is not hash-based');
        };
    } else {
        no strict 'refs';

        return ${$self.'::__cag_'.$set} = $val;
    };
}

=head2 get_super_paths

Returns a list of 'parent' or 'super' class names that the current class inherited from.

=cut

sub get_super_paths {
    my $class = blessed $_[0] || $_[0];

    return Class::ISA::super_path($class);
};

1;

=head1 AUTHORS

Matt S. Trout <mst@shadowcatsystems.co.uk>
Christopher H. Laco <claco@chrislaco.com>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

