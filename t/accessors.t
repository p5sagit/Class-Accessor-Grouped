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

use AccessorGroupsSubclass;

{
    my $obj = AccessorGroups->new;
    my $class = ref $obj;
    my $name = 'multiple1';
    my $alias = "_${name}_accessor";
    my $accessor = $obj->can($name);
    my $alias_accessor = $obj->can($alias);
    isnt(sub_name($accessor), '__ANON__', 'accessor is named');
    isnt(sub_name($alias_accessor), '__ANON__', 'alias is named');
    is(sub_fullname($accessor), join('::',$class,$name), 'accessor FQ name');
    is(sub_fullname($alias_accessor), join('::',$class,$alias), 'alias FQ name');

    my $warned = 0;
    local $SIG{__WARN__} = sub {
        if  (shift =~ /DESTROY/i) {
            $warned++;
        };
    };

    no warnings qw/once/;
    local *AccessorGroups::DESTROY = sub {};

    $class->mk_group_accessors('warnings', 'DESTROY');
    ok($warned);
};


my $obj = AccessorGroupsSubclass->new;

my $test_accessors = {
    singlefield => {
        is_xs => $use_xs,
        has_extra => 1,
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
    my $extra = $test_accessors->{$name}{has_extra};

    can_ok($obj, $name, $alias);
    ok(!$obj->can($field))
      if $field ne $name;

    is($obj->$name, undef);
    is($obj->$alias, undef);

    # get/set via name
    is($obj->$name('a'), 'a');
    is($obj->$name, 'a');
    is($obj->{$field}, $extra ? 'a Extra tackled on' : 'a');

    # alias gets same as name
    is($obj->$alias, 'a');

    # get/set via alias
    is($obj->$alias('b'), 'b');
    is($obj->$alias, 'b');
    is($obj->{$field}, $extra ? 'b Extra tackled on' : 'b');

    # alias gets same as name
    is($obj->$name, 'b');
};

# important
1;
