package Class::Accessor::Grouped;
use strict;
use warnings;
use Carp ();
use Scalar::Util ();
use MRO::Compat;
use Sub::Name ();

our $VERSION = '0.09006';
$VERSION = eval $VERSION;

# when changing minimum version don't forget to adjust L</PERFROMANCE> as well
our $__minimum_xsa_version = '1.06';

our $USE_XS;
# the unless defined is here so that we can override the value
# before require/use, *regardless* of the state of $ENV{CAG_USE_XS}
$USE_XS = $ENV{CAG_USE_XS}
    unless defined $USE_XS;

my $xsa_loaded;

my $load_xsa = sub {
    return if $xsa_loaded++;
    require Class::XSAccessor;
    Class::XSAccessor->VERSION($__minimum_xsa_version);
};

my $use_xs = sub {
    if (defined $USE_XS) {
        $load_xsa->() if ($USE_XS && ! $xsa_loaded);
        return $USE_XS;
    }

    $USE_XS = 0;

    # Class::XSAccessor is segfaulting on win32, in some
    # esoteric heavily-threaded scenarios
    # Win32 users can set $USE_XS/CAG_USE_XS to try to use it anyway
    if ($^O ne 'MSWin32') {
        local $@;
        eval { $load_xsa->(); $USE_XS = 1 };
    }

    return $USE_XS;
};

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

If you want to mimic Class::Accessor's mk_accessors $group has to be 'simple'
to tell Class::Accessor::Grouped to use its own get_simple and set_simple
methods.

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
        my $class = Scalar::Util::blessed $self || $self;

        # So we don't have to do lots of lookups inside the loop.
        $maker = $self->can($maker) unless ref $maker;

        foreach (@fields) {
            if( $_ eq 'DESTROY' ) {
                Carp::carp("Having a data accessor named DESTROY  in ".
                             "'$class' is unwise.");
            }

            my ($name, $field) = (ref $_)
                ? (@$_)
                : ($_, $_)
            ;

            my $alias = "_${name}_accessor";

            for my $meth ($name, $alias) {

                # the maker may elect to not return anything, meaning it already
                # installed the coderef for us
                my $cref = $self->$maker($group, $field, $meth)
                    or next;

                my $fq_meth = join('::', $class, $meth);

                *$fq_meth = Sub::Name::subname($fq_meth, $cref);
                    #unless defined &{$class."\:\:$field"}
            }
        }
    }
}

=head2 mk_group_ro_accessors

=over 4

=item Arguments: $group, @fieldspec

Returns: none

=back

Creates a set of read only accessors in a given group. Identical to
L</mk_group_accessors> but accessors will throw an error if passed a value
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
L</mk_group_accessors> but accessors will throw an error if not passed a
value rather than getting the value.

=cut

sub mk_group_wo_accessors {
    my($self, $group, @fields) = @_;

    $self->_mk_group_accessors('make_group_wo_accessor', $group, @fields);
}

=head2 make_group_accessor

=over 4

=item Arguments: $group, $field, $method

Returns: \&accessor_coderef ?

=back

Called by mk_group_accessors for each entry in @fieldspec. Either returns
a coderef which will be installed at C<&__PACKAGE__::$method>, or returns
C<undef> if it elects to install the coderef on its own.

=cut

sub make_group_accessor {
    my ($class, $group, $field, $name) = @_;

    if ( $group eq 'simple' && $use_xs->() ) {
        Class::XSAccessor->import({
            replace => 1,
            class => $class,
            accessors => {
                $name => $field,
            },
        });
        return;
    }

    my $set = "set_$group";
    my $get = "get_$group";

    $field =~ s/'/\\'/g;

    # eval for faster fastiness
    my $code = eval "sub {
        if(\@_ > 1) {
            return shift->$set('$field', \@_);
        }
        else {
            return shift->$get('$field');
        }
    };";
    Carp::croak $@ if $@;

    return $code;
}

=head2 make_group_ro_accessor

=over 4

=item Arguments: $group, $field, $method

Returns: \&accessor_coderef ?

=back

Called by mk_group_ro_accessors for each entry in @fieldspec. Either returns
a coderef which will be installed at C<&__PACKAGE__::$method>, or returns
C<undef> if it elects to install the coderef on its own.

=cut

sub make_group_ro_accessor {
    my($class, $group, $field, $name) = @_;

    if ( $group eq 'simple' && $use_xs->() ) {
        Class::XSAccessor->import({
            replace => 1,
            class => $class,
            getters => {
                $name => $field,
            },
        });
        return;
    }

    my $get = "get_$group";

    $field =~ s/'/\\'/g;

    my $code = eval "sub {
        if(\@_ > 1) {
            my \$caller = caller;
            Carp::croak(\"'\$caller' cannot alter the value of '$field' on \".
                        \"objects of class '$class'\");
        }
        else {
            return shift->$get('$field');
        }
    };";
    Carp::croak $@ if $@;

    return $code;
}

=head2 make_group_wo_accessor

=over 4

=item Arguments: $group, $field, $method

Returns: \&accessor_coderef ?

=back

Called by mk_group_wo_accessors for each entry in @fieldspec. Either returns
a coderef which will be installed at C<&__PACKAGE__::$method>, or returns
C<undef> if it elects to install the coderef on its own.

=cut

sub make_group_wo_accessor {
    my($class, $group, $field, $name) = @_;

    if ( $group eq 'simple' && $use_xs->() ) {
        Class::XSAccessor->import({
            replace => 1,
            class => $class,
            setters => {
                $name => $field,
            },
        });
        return;
    }

    my $set = "set_$group";

    $field =~ s/'/\\'/g;

    my $code = eval "sub {
        unless (\@_ > 1) {
            my \$caller = caller;
            Carp::croak(\"'\$caller' cannot access the value of '$field' on \".
                        \"objects of class '$class'\");
        }
        else {
            return shift->$set('$field', \@_);
        }
    };";
    Carp::croak $@ if $@;

    return $code;
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
  return $_[0]->{$_[1]};
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
  return $_[0]->{$_[1]} = $_[2];
}


=head2 get_inherited

=over 4

=item Arguments: $field

Returns: $value

=back

Simple getter for Classes and hash-based objects which returns the value for
the field name passed as an argument. This behaves much like
L<Class::Data::Accessor> where the field can be set in a base class,
inherited and changed in subclasses, and inherited and changed for object
instances.

=cut

sub get_inherited {
    my $class;

    if ( ($class = ref $_[0]) && Scalar::Util::blessed $_[0]) {
        if (Scalar::Util::reftype $_[0] eq 'HASH') {
          return $_[0]->{$_[1]} if exists $_[0]->{$_[1]};
        }
        else {
          Carp::croak('Cannot get inherited value on an object instance that is not hash-based');
        }
    }
    else {
        $class = $_[0];
    }

    no strict 'refs';
    no warnings qw/uninitialized/;

    my $cag_slot = '::__cag_'. $_[1];
    return ${$class.$cag_slot} if defined(${$class.$cag_slot});

    # we need to be smarter about recalculation, as @ISA (thus supers) can very well change in-flight
    my $cur_gen = mro::get_pkg_gen ($class);
    if ( $cur_gen != ${$class.'::__cag_pkg_gen__'} ) {
        @{$class.'::__cag_supers__'} = $_[0]->get_super_paths;
        ${$class.'::__cag_pkg_gen__'} = $cur_gen;
    }

    for (@{$class.'::__cag_supers__'}) {
        return ${$_.$cag_slot} if defined(${$_.$cag_slot});
    };

    return undef;
}

=head2 set_inherited

=over 4

=item Arguments: $field, $new_value

Returns: $new_value

=back

Simple setter for Classes and hash-based objects which sets and then returns
the value for the field name passed as an argument. When called on a hash-based
object it will set the appropriate hash key value. When called on a class, it
will set a class level variable.

B<Note:>: This method will die if you try to set an object variable on a non
hash-based object.

=cut

sub set_inherited {
    if (Scalar::Util::blessed $_[0]) {
        if (Scalar::Util::reftype $_[0] eq 'HASH') {
            return $_[0]->{$_[1]} = $_[2];
        } else {
            Carp::croak('Cannot set inherited value on an object instance that is not hash-based');
        };
    } else {
        no strict 'refs';

        return ${$_[0].'::__cag_'.$_[1]} = $_[2];
    };
}

=head2 get_component_class

=over 4

=item Arguments: $field

Returns: $value

=back

Gets the value of the specified component class.

    __PACKAGE__->mk_group_accessors('component_class' => 'result_class');

    $self->result_class->method();

    ## same as
    $self->get_component_class('result_class')->method();

=cut

sub get_component_class {
    return $_[0]->get_inherited($_[1]);
};

=head2 set_component_class

=over 4

=item Arguments: $field, $class

Returns: $new_value

=back

Inherited accessor that automatically loads the specified class before setting
it. This method will die if the specified class could not be loaded.

    __PACKAGE__->mk_group_accessors('component_class' => 'result_class');
    __PACKAGE__->result_class('MyClass');

    $self->result_class->method();

=cut

sub set_component_class {
    if ($_[2]) {
        local $^W = 0;
        require Class::Inspector;
        if (Class::Inspector->installed($_[2]) && !Class::Inspector->loaded($_[2])) {
            eval "use $_[2]";

            Carp::croak("Could not load $_[1] '$_[2]': ", $@) if $@;
        };
    };

    return $_[0]->set_inherited($_[1], $_[2]);
};

=head2 get_super_paths

Returns a list of 'parent' or 'super' class names that the current class inherited from.

=cut

sub get_super_paths {
    return @{mro::get_linear_isa( ref($_[0]) || $_[0] )};
};

1;

=head1 PERFORMANCE

To provide total flexibility L<Class::Accessor::Grouped> calls methods
internally while performing get/set actions, which makes it noticeably
slower than similar modules. To compensate, this module will automatically
use the insanely fast L<Class::XSAccessor> to generate the C<simple>-group
accessors, if L<< Class::XSAccessor >= 1.06|Class::XSAccessor >> is
available on your system.

=head2 Benchmark

This is the result of a set/get/set loop benchmark on perl 5.12.1 with
thread support, showcasing most popular accessor builders: L<Moose>, L<Mouse>,
L<CAF|Class::Accessor::Fast>, L<CAF_XS|Class::Accessor::Fast::XS>
and L<XSA|Class::XSAccessor>:

            Rate     CAG   moOse     CAF HANDMADE  CAF_XS moUse_XS CAG_XS     XSA
 CAG      1777/s      --    -27%    -29%     -36%    -62%     -67%   -72%    -73%
 moOse    2421/s     36%      --     -4%     -13%    -48%     -55%   -61%    -63%
 CAF      2511/s     41%      4%      --     -10%    -47%     -53%   -60%    -61%
 HANDMADE 2791/s     57%     15%     11%       --    -41%     -48%   -56%    -57%
 CAF_XS   4699/s    164%     94%     87%      68%      --     -13%   -25%    -28%
 moUse_XS 5375/s    203%    122%    114%      93%     14%       --   -14%    -18%
 CAG_XS   6279/s    253%    159%    150%     125%     34%      17%     --     -4%
 XSA      6515/s    267%    169%    159%     133%     39%      21%     4%      --

Benchmark program is available in the root of the
L<repository|http://search.cpan.org/dist/Class-Accessor-Grouped/>:

=head2 Notes on Class::XSAccessor

While L<Class::XSAccessor> works surprisingly well for the amount of black
magic it tries to pull off, it's still black magic. At present (Sep 2010)
the module is known to have problems on Windows under heavy thread-stress
(e.g. Win32+Apache+mod_perl). Thus for the time being L<Class::XSAccessor>
will not be used automatically if you are running under C<MSWin32>.

You can force the use of L<Class::XSAccessor> before creating a particular
C<simple> accessor by either manipulating the global variable
C<$Class::Accessor::Grouped::USE_XS>, or you can do so before runtime via the
C<CAG_USE_XS> environment variable.

=head1 AUTHORS

Matt S. Trout <mst@shadowcatsystems.co.uk>

Christopher H. Laco <claco@chrislaco.com>

=head1 CONTRIBUTORS

Caelum: Rafael Kitover <rkitover@cpan.org>

groditi: Guillermo Roditi <groditi@cpan.org>

Jason Plum <jason.plum@bmmsi.com>

ribasushi: Peter Rabbitson <ribasushi@cpan.org>


=head1 COPYRIGHT & LICENSE

Copyright (c) 2006-2010 Matt S. Trout <mst@shadowcatsystems.co.uk>

This program is free software; you can redistribute it and/or modify
it under the same terms as perl itself.

=cut
