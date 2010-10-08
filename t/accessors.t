use Test::More tests => 62;
use strict;
use warnings;
use lib 't/lib';
use Sub::Identify qw/sub_name sub_fullname/;

# we test the pure-perl versions only, but allow overrides
# from the accessor_xs test-umbrella
# Also make sure a rogue envvar will not interfere with
# things
my $use_xs;
BEGIN {
    $Class::Accessor::Grouped::USE_XS = 0
        unless defined $Class::Accessor::Grouped::USE_XS;
    $ENV{CAG_USE_XS} = 1;
    $use_xs = $Class::Accessor::Grouped::USE_XS;
};

use AccessorGroups;

my $class = AccessorGroups->new;

{
    my $warned = 0;

    local $SIG{__WARN__} = sub {
        if  (shift =~ /DESTROY/i) {
            $warned++;
        };
    };

    $class->mk_group_accessors('warnings', 'DESTROY');

    ok($warned);

    # restore non-accessorized DESTROY
    no warnings;
    *AccessorGroups::DESTROY = sub {};
};

{
  my $class_name = ref $class;
  my $name = 'multiple1';
  my $alias = "_${name}_accessor";
  my $accessor = $class->can($name);
  my $alias_accessor = $class->can($alias);
  isnt(sub_name($accessor), '__ANON__', 'accessor is named');
  isnt(sub_name($alias_accessor), '__ANON__', 'alias is named');
  is(sub_fullname($accessor), join('::',$class_name,$name), 'accessor FQ name');
  is(sub_fullname($alias_accessor), join('::',$class_name,$alias), 'alias FQ name');
}

my $test_accessors = {
    singlefield => {
        is_xs => $use_xs,
    },
    multiple1 => {
    },
    multiple2 => {
    },
    lr1name => {
        custom_field => 'lr1;field',
    },
    lr2name => {
        custom_field => "lr2'field",
    },
};


for my $name (sort keys %$test_accessors) {
    my $alias = "_${name}_accessor";
    my $field = $test_accessors->{$name}{custom_field} || $name;

    can_ok($class, $name, $alias);
    ok(!$class->can($field))
      if $field ne $name;

    is($class->$name, undef);
    is($class->$alias, undef);

    # get/set via name
    is($class->$name('a'), 'a');
    is($class->$name, 'a');
    is($class->{$field}, 'a');

    # alias gets same as name
    is($class->$alias, 'a');

    # get/set via alias
    is($class->$alias('b'), 'b');
    is($class->$alias, 'b');
    is($class->{$field}, 'b');

    # alias gets same as name
    is($class->$name, 'b');
};

# important
1;
