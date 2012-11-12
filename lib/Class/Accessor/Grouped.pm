package Class::Accessor::Grouped;
use strict;
use warnings;
use Carp ();
use Scalar::Util ();
use Module::Runtime ();

BEGIN {
  # use M::R to work around the 5.8 require bugs
  if ($] < 5.009_005) {
    Module::Runtime::require_module('MRO::Compat');
  }
  else {
    require mro;
  }
}

our $VERSION = '0.10007';
$VERSION = eval $VERSION if $VERSION =~ /_/; # numify for warning-free dev releases

# when changing minimum version don't forget to adjust Makefile.PL as well
our $__minimum_xsa_version;
BEGIN { $__minimum_xsa_version = '1.15' }

our $USE_XS;
# the unless defined is here so that we can override the value
# before require/use, *regardless* of the state of $ENV{CAG_USE_XS}
$USE_XS = $ENV{CAG_USE_XS}
  unless defined $USE_XS;

BEGIN {
  package # hide from PAUSE
    __CAG_ENV__;

  die "Huh?! No minimum C::XSA version?!\n"
    unless $__minimum_xsa_version;

  local $@;
  require constant;

  # individual (one const at a time) imports so we are 5.6.2 compatible
  # if we can - why not ;)
  constant->import( NO_SUBNAME => eval {
    Module::Runtime::require_module('Sub::Name')
  } ? 0 : "$@" );

  my $found_cxsa;
  constant->import( NO_CXSA => ( NO_SUBNAME() || ( eval {
    Module::Runtime::require_module('Class::XSAccessor');
    $found_cxsa = Class::XSAccessor->VERSION;
    Class::XSAccessor->VERSION($__minimum_xsa_version);
  } ? 0 : "$@" ) ) );

  if (NO_CXSA() and $found_cxsa and !$ENV{CAG_OLD_XS_NOWARN}) {
    warn(
      'The installed version of Class::XSAccessor is too old '
    . "(v$found_cxsa < v$__minimum_xsa_version). Please upgrade "
    . "to instantly quadruple the performance of 'simple' accessors. "
    . 'Set $ENV{CAG_OLD_XS_NOWARN} if you wish to disable this '
    . "warning.\n"
    );
  }

  constant->import( BROKEN_GOTO => ($] < '5.008009') ? 1 : 0 );

  constant->import( UNSTABLE_DOLLARAT => ($] < '5.013002') ? 1 : 0 );

  constant->import( TRACK_UNDEFER_FAIL => (
    $INC{'Test/Builder.pm'} || $INC{'Test/Builder2.pm'}
      and
    $0 =~ m|^ x?t / .+ \.t $|x
  ) ? 1 : 0 );
}

# Yes this method is undocumented
# Yes it should be a private coderef like all the rest at the end of this file
# No we can't do that (yet) because the DBIC-CDBI compat layer overrides it
# %$*@!?&!&#*$!!!
sub _mk_group_accessors {
  my($self, $maker, $group, @fields) = @_;
  my $class = length (ref ($self) ) ? ref ($self) : $self;

  no strict 'refs';
  no warnings 'redefine';

  # So we don't have to do lots of lookups inside the loop.
  $maker = $self->can($maker) unless ref $maker;

  for (@fields) {

    my ($name, $field) = (ref $_) ? (@$_) : ($_, $_);

    Carp::croak("Illegal accessor name '$name'")
      unless $name =~ /\A[A-Z_a-z][0-9A-Z_a-z]*\z/;

    Carp::carp("Having a data accessor named '$name' in '$class' is unwise.")
      if $name =~ /\A(?: DESTROY | AUTOLOAD | CLONE )\z/x;

    my $alias = "_${name}_accessor";

    for ($name, $alias) {

      # the maker may elect to not return anything, meaning it already
      # installed the coderef for us (e.g. lack of Sub::Name)
      my $cref = $self->$maker($group, $field, $_)
        or next;

      my $fq_meth = "${class}::$_";

      *$fq_meth = Sub::Name::subname($fq_meth, $cref);
        #unless defined &{$class."\:\:$field"}
    }
  }
};

# $gen_accessor coderef is setup at the end for clarity
my $gen_accessor;

=head1 NAME

Class::Accessor::Grouped - Lets you build groups of accessors

=head1 SYNOPSIS

 use base 'Class::Accessor::Grouped';

 # make basic accessors for objects
 __PACKAGE__->mk_group_accessors(simple => qw(id name email));

 # make accessor that works for objects and classes
 __PACKAGE__->mk_group_accessors(inherited => 'awesome_level');

=head1 DESCRIPTION

This class lets you build groups of accessors that will call different
getters and setters.

=head1 METHODS

=head2 mk_group_accessors

 __PACKAGE__->mk_group_accessors(simple => 'hair_length', [ hair_color => 'hc' ]);

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

=head2 mk_group_ro_accessors

 __PACKAGE__->mk_group_ro_accessors(simple => 'birthdate', [ social_security_number => 'ssn' ]);

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
  return;
}

=head2 mk_group_wo_accessors

 __PACKAGE__->mk_group_wo_accessors(simple => 'lie', [ subject => 'subj' ]);

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
  return;
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
  $_[0]->{$_[1]};
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
  $_[0]->{$_[1]} = $_[2];
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
  if ( length (ref ($_[0]) ) ) {
    if (Scalar::Util::reftype $_[0] eq 'HASH') {
      return $_[0]->{$_[1]} if exists $_[0]->{$_[1]};
      # everything in @_ is aliased, an assignment won't work
      splice @_, 0, 1, ref($_[0]);
    }
    else {
      Carp::croak('Cannot get inherited value on an object instance that is not hash-based');
    }
  }

  # if we got this far there is nothing in the instance
  # OR this is a class call
  # in any case $_[0] contains the class name (see splice above)
  no strict 'refs';
  no warnings 'uninitialized';

  my $cag_slot = '::__cag_'. $_[1];
  return ${$_[0].$cag_slot} if defined(${$_[0].$cag_slot});

  do { return ${$_.$cag_slot} if defined(${$_.$cag_slot}) }
    for $_[0]->get_super_paths;

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
  if (length (ref ($_[0]) ) ) {
    if (Scalar::Util::reftype $_[0] eq 'HASH') {
      return $_[0]->{$_[1]} = $_[2];
    } else {
      Carp::croak('Cannot set inherited value on an object instance that is not hash-based');
    };
  }

  no strict 'refs';
  ${$_[0].'::__cag_'.$_[1]} = $_[2];
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
  $_[0]->get_inherited($_[1]);
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
  if (defined $_[2] and length $_[2]) {
    # disable warnings, and prevent $_ being eaten away by a behind-the-scenes
    # module loading
    local ($^W, $_);

    if (__CAG_ENV__::UNSTABLE_DOLLARAT) {
      my $err;
      {
        local $@;
        eval { Module::Runtime::use_package_optimistically($_[2]) }
          or $err = $@;
      }
      Carp::croak("Could not load $_[1] '$_[2]': $err") if defined $err;

    }
    else {
      eval { Module::Runtime::use_package_optimistically($_[2]) }
        or Carp::croak("Could not load $_[1] '$_[2]': $@");
    }
  };

  $_[0]->set_inherited($_[1], $_[2]);
};

=head1 INTERNAL METHODS

These methods are documented for clarity, but are never meant to be called
directly, and are not really meant for overriding either.

=head2 get_super_paths

Returns a list of 'parent' or 'super' class names that the current class
inherited from. This is what drives the traversal done by L</get_inherited>.

=cut

sub get_super_paths {
  # get_linear_isa returns the class itself as the 1st element
  # use @_ as a pre-allocated scratch array
  (undef, @_) = @{mro::get_linear_isa( length( ref($_[0]) ) ? ref($_[0]) : $_[0] )};
  @_;
};

=head2 make_group_accessor

 __PACKAGE__->make_group_accessor('simple', 'hair_length', 'hair_length');
 __PACKAGE__->make_group_accessor('simple', 'hc', 'hair_color');

=over 4

=item Arguments: $group, $field, $accessor

Returns: \&accessor_coderef ?

=back

Called by mk_group_accessors for each entry in @fieldspec. Either returns
a coderef which will be installed at C<&__PACKAGE__::$accessor>, or returns
C<undef> if it elects to install the coderef on its own.

=cut

sub make_group_accessor { $gen_accessor->('rw', @_) }

=head2 make_group_ro_accessor

 __PACKAGE__->make_group_ro_accessor('simple', 'birthdate', 'birthdate');
 __PACKAGE__->make_group_ro_accessor('simple', 'ssn', 'social_security_number');

=over 4

=item Arguments: $group, $field, $accessor

Returns: \&accessor_coderef ?

=back

Called by mk_group_ro_accessors for each entry in @fieldspec. Either returns
a coderef which will be installed at C<&__PACKAGE__::$accessor>, or returns
C<undef> if it elects to install the coderef on its own.

=cut

sub make_group_ro_accessor { $gen_accessor->('ro', @_) }

=head2 make_group_wo_accessor

 __PACKAGE__->make_group_wo_accessor('simple', 'lie', 'lie');
 __PACKAGE__->make_group_wo_accessor('simple', 'subj', 'subject');

=over 4

=item Arguments: $group, $field, $accessor

Returns: \&accessor_coderef ?

=back

Called by mk_group_wo_accessors for each entry in @fieldspec. Either returns
a coderef which will be installed at C<&__PACKAGE__::$accessor>, or returns
C<undef> if it elects to install the coderef on its own.

=cut

sub make_group_wo_accessor { $gen_accessor->('wo', @_) }


=head1 PERFORMANCE

To provide total flexibility L<Class::Accessor::Grouped> calls methods
internally while performing get/set actions, which makes it noticeably
slower than similar modules. To compensate, this module will automatically
use the insanely fast L<Class::XSAccessor> to generate the C<simple>-group
accessors if this module is available on your system.

=head2 Benchmark

This is the result of a set/get/set loop benchmark on perl 5.12.1 with
thread support, showcasing most popular accessor builders: L<Moose>, L<Mouse>,
L<Moo>, L<CAF|Class::Accessor::Fast>, L<CAF_XS|Class::Accessor::Fast::XS>,
L<XSA|Class::XSAccessor>, and L<CAF_XSA|Class::XSAccessor::Compat>:

           Rate  CAG moOse  CAF moUse  moo HANDMADE CAF_XS moUse_XS moo_XS CAF_XSA  XSA CAG_XS
 CAG      169/s   --  -21% -24%  -32% -32%     -34%   -59%     -63%   -67%    -67% -67%   -67%
 moOse    215/s  27%    --  -3%  -13% -13%     -15%   -48%     -53%   -58%    -58% -58%   -58%
 CAF      222/s  31%    3%   --  -10% -10%     -13%   -46%     -52%   -57%    -57% -57%   -57%
 moUse    248/s  46%   15%  11%    --  -0%      -3%   -40%     -46%   -52%    -52% -52%   -52%
 moo      248/s  46%   15%  11%    0%   --      -3%   -40%     -46%   -52%    -52% -52%   -52%
 HANDMADE 255/s  50%   18%  14%    3%   3%       --   -38%     -45%   -50%    -51% -51%   -51%
 CAF_XS   411/s 143%   91%  85%   66%  66%      61%     --     -11%   -20%    -20% -21%   -21%
 moUse_XS 461/s 172%  114% 107%   86%  86%      81%    12%       --   -10%    -11% -11%   -11%
 moo_XS   514/s 204%  139% 131%  107% 107%     102%    25%      12%     --     -0%  -1%    -1%
 CAF_XSA  516/s 205%  140% 132%  108% 108%     103%    26%      12%     0%      --  -0%    -0%
 XSA      519/s 206%  141% 133%  109% 109%     104%    26%      13%     1%      0%   --    -0%
 CAG_XS   519/s 206%  141% 133%  109% 109%     104%    26%      13%     1%      0%   0%     --

Benchmark program is available in the root of the
L<repository|http://search.cpan.org/dist/Class-Accessor-Grouped/>:

=head2 Notes on Class::XSAccessor

You can force (or disable) the use of L<Class::XSAccessor> before creating a
particular C<simple> accessor by either manipulating the global variable
C<$Class::Accessor::Grouped::USE_XS> to true or false (preferably with
L<localization|perlfunc/local>, or you can do so before runtime via the
C<CAG_USE_XS> environment variable.

Since L<Class::XSAccessor> has no knowledge of L</get_simple> and
L</set_simple> this module does its best to detect if you are overriding
one of these methods and will fall back to using the perl version of the
accessor in order to maintain consistency. However be aware that if you
enable use of C<Class::XSAccessor> (automatically or explicitly), create
an object, invoke a simple accessor on that object, and B<then> manipulate
the symbol table to install a C<get/set_simple> override - you get to keep
all the pieces.

=head1 AUTHORS

Matt S. Trout <mst@shadowcatsystems.co.uk>

Christopher H. Laco <claco@chrislaco.com>

=head1 CONTRIBUTORS

Caelum: Rafael Kitover <rkitover@cpan.org>

frew: Arthur Axel "fREW" Schmidt <frioux@gmail.com>

groditi: Guillermo Roditi <groditi@cpan.org>

Jason Plum <jason.plum@bmmsi.com>

ribasushi: Peter Rabbitson <ribasushi@cpan.org>


=head1 COPYRIGHT & LICENSE

Copyright (c) 2006-2010 Matt S. Trout <mst@shadowcatsystems.co.uk>

This program is free software; you can redistribute it and/or modify
it under the same terms as perl itself.

=cut

########################################################################
########################################################################
########################################################################
#
# Here be many angry dragons
# (all code is in private coderefs since everything inherits CAG)
#
########################################################################
########################################################################

# Autodetect unless flag supplied
my $xsa_autodetected;
if (! defined $USE_XS) {
  $USE_XS = __CAG_ENV__::NO_CXSA ? 0 : 1;
  $xsa_autodetected++;
}

my $perlstring;
if ($] < '5.008') {
  require Data::Dumper;
  my $d = Data::Dumper->new([])->Indent(0)->Purity(0)->Pad('')->Useqq(1)->Terse(1)->Freezer('')->Toaster('');
  $perlstring = sub { $d->Values([shift])->Dump };
}
else {
  require B;
  $perlstring = \&B::perlstring;
}


my $maker_templates = {
  rw => {
    cxsa_call => 'accessors',
    pp_generator => sub {
      # my ($group, $fieldname) = @_;
      my $quoted_fieldname = $perlstring->($_[1]);
      sprintf <<'EOS', ($_[0], $quoted_fieldname) x 2;

@_ > 1
  ? shift->set_%s(%s, @_)
  : shift->get_%s(%s)
EOS

    },
  },
  ro => {
    cxsa_call => 'getters',
    pp_generator => sub {
      # my ($group, $fieldname) = @_;
      my $quoted_fieldname = $perlstring->($_[1]);
      sprintf  <<'EOS', $_[0], $quoted_fieldname;

@_ > 1
  ? do {
    my ($meth) = (caller(0))[3] =~ /([^\:]+)$/;
    my $class = length( ref($_[0]) ) ? ref($_[0]) : $_[0];
    Carp::croak(
      "'$meth' cannot alter its value (read-only attribute of class $class)"
    );
  }
  : shift->get_%s(%s)
EOS

    },
  },
  wo => {
    cxsa_call => 'setters',
    pp_generator => sub {
      # my ($group, $fieldname) = @_;
      my $quoted_fieldname = $perlstring->($_[1]);
      sprintf  <<'EOS', $_[0], $quoted_fieldname;

@_ > 1
  ? shift->set_%s(%s, @_)
  : do {
    my ($meth) = (caller(0))[3] =~ /([^\:]+)$/;
    my $class = length( ref($_[0]) ) ? ref($_[0]) : $_[0];
    Carp::croak(
      "'$meth' cannot access its value (write-only attribute of class $class)"
    );
  }
EOS

    },
  },
};

my $cag_eval = sub {
  #my ($src, $no_warnings, $err_msg) = @_;

  my $src = sprintf "{ %s warnings; use strict; no strict 'refs'; %s }",
    $_[1] ? 'no' : 'use',
    $_[0],
  ;

  my (@rv, $err);
  {
    local $@ if __CAG_ENV__::UNSTABLE_DOLLARAT;
    wantarray
      ? @rv = eval $src
      : $rv[0] = eval $src
    ;
    $err = $@ if $@ ne '';
  }

  Carp::croak(join ': ', ($_[2] || 'String-eval failed'), "$err\n$src\n" )
    if defined $err;

  wantarray ? @rv : $rv[0];
};

my ($accessor_maker_cache, $no_xsa_warned_classes);

# can't use pkg_gen to track this stuff, as it doesn't
# detect superclass mucking
my $original_simple_getter = __PACKAGE__->can ('get_simple');
my $original_simple_setter = __PACKAGE__->can ('set_simple');

# Note!!! Unusual signature
$gen_accessor = sub {
  my ($type, $class, $group, $field, $methname) = @_;
  $class = ref $class if length ref $class;

  # When installing an XSA simple accessor, we need to make sure we are not
  # short-circuiting a (compile or runtime) get_simple/set_simple override.
  # What we do here is install a lazy first-access check, which will decide
  # the ultimate coderef being placed in the accessor slot
  #
  # Also note that the *original* class will always retain this shim, as
  # different branches inheriting from it may have different overrides.
  # Thus the final method (properly labeled and all) is installed in the
  # calling-package's namespace
  if ($USE_XS and $group eq 'simple') {
    die sprintf( "Class::XSAccessor requested but not available:\n%s\n", __CAG_ENV__::NO_CXSA )
      if __CAG_ENV__::NO_CXSA;

    my ($expected_cref, $cached_implementation);
    my $ret = $expected_cref = sub {
      my $current_class = length (ref ($_[0] ) ) ? ref ($_[0]) : $_[0];

      # $cached_implementation will be set only if the shim got
      # 'around'ed, in which case it is handy to avoid re-running
      # this block over and over again
      my $resolved_implementation = $cached_implementation->{$current_class} || do {
        if (
          ($current_class->can('get_simple')||0) == $original_simple_getter
            &&
          ($current_class->can('set_simple')||0) == $original_simple_setter
        ) {
          # nothing has changed, might as well use the XS crefs
          #
          # note that by the time this code executes, we already have
          # *objects* (since XSA works on 'simple' only by definition).
          # If someone is mucking with the symbol table *after* there
          # are some objects already - look! many, shiny pieces! :)
          #
          # The weird breeder thingy is because XSA does not have an
          # interface returning *just* a coderef, without installing it
          # anywhere :(
          Class::XSAccessor->import(
            replace => 1,
            class => '__CAG__XSA__BREEDER__',
            $maker_templates->{$type}{cxsa_call} => {
              $methname => $field,
            },
          );
          __CAG__XSA__BREEDER__->can($methname);
        }
        else {
          if (! $xsa_autodetected and ! $no_xsa_warned_classes->{$current_class}++) {
            # not using Carp since the line where this happens doesn't mean much
            warn 'Explicitly requested use of Class::XSAccessor disabled for objects of class '
              . "'$current_class' inheriting from '$class' due to an overriden get_simple and/or "
              . "set_simple\n";
          }

          do {
            # that's faster than local
            $USE_XS = 0;
            my $c = $gen_accessor->($type, $class, 'simple', $field, $methname);
            $USE_XS = 1;
            $c;
          };
        }
      };

      # if after this shim was created someone wrapped it with an 'around',
      # we can not blindly reinstall the method slot - we will destroy the
      # wrapper. Silently chain execution further...
      if ( !$expected_cref or $expected_cref != ($current_class->can($methname)||0) ) {

        # there is no point in re-determining it on every subsequent call,
        # just store for future reference
        $cached_implementation->{$current_class} ||= $resolved_implementation;

        # older perls segfault if the cref behind the goto throws
        # http://rt.perl.org/rt3/Public/Bug/Display.html?id=35878
        return $resolved_implementation->(@_) if __CAG_ENV__::BROKEN_GOTO;

        goto $resolved_implementation;
      }

      if (__CAG_ENV__::TRACK_UNDEFER_FAIL) {
        my $deferred_calls_seen = do {
          no strict 'refs';
          \%{"${current_class}::__cag_deferred_xs_shim_invocations"}
        };
        my @cframe = caller(0);
        if (my $already_seen = $deferred_calls_seen->{$cframe[3]}) {
          Carp::carp (
            "Deferred version of method $cframe[3] invoked more than once (originally "
          . "invoked at $already_seen). This is a strong indication your code has "
          . 'cached the original ->can derived method coderef, and is using it instead '
          . 'of the proper method re-lookup, causing minor performance regressions'
          );
        }
        else {
          $deferred_calls_seen->{$cframe[3]} = "$cframe[1] line $cframe[2]";
        }
      }

      # install the resolved implementation into the code slot so we do not
      # come here anymore (hopefully)
      # since XSAccessor was available - so is Sub::Name
      {
        no strict 'refs';
        no warnings 'redefine';

        my $fq_name = "${current_class}::${methname}";
        *$fq_name = Sub::Name::subname($fq_name, $resolved_implementation);

        # need to update what the shim expects too *in case* its
        # ->can was cached for some moronic reason
        $expected_cref = $resolved_implementation;
        Scalar::Util::weaken($expected_cref);
      }

      # older perls segfault if the cref behind the goto throws
      # http://rt.perl.org/rt3/Public/Bug/Display.html?id=35878
      return $resolved_implementation->(@_) if __CAG_ENV__::BROKEN_GOTO;

      goto $resolved_implementation;
    };

    Scalar::Util::weaken($expected_cref); # to break the self-reference
    $ret;
  }

  # no Sub::Name - just install the coderefs directly (compiling every time)
  elsif (__CAG_ENV__::NO_SUBNAME) {
    my $src = $accessor_maker_cache->{source}{$type}{$group}{$field} ||=
      $maker_templates->{$type}{pp_generator}->($group, $field);

    $cag_eval->(
      "no warnings 'redefine'; sub ${class}::${methname} { $src }; 1",
    );

    undef;  # so that no further attempt will be made to install anything
  }

  # a coderef generator with a variable pad (returns a fresh cref on every invocation)
  else {
    ($accessor_maker_cache->{pp}{$type}{$group}{$field} ||= do {
      my $src = $accessor_maker_cache->{source}{$type}{$group}{$field} ||=
        $maker_templates->{$type}{pp_generator}->($group, $field);

      $cag_eval->( "sub { my \$dummy; sub { \$dummy if 0; $src } }" );
    })->()
  }
};

1;
