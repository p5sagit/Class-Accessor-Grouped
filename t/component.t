use Test::More tests => 7;
use strict;
use warnings;
use lib 't/lib';
use Class::Inspector;
use AccessorGroups;

is(AccessorGroups->result_class, undef);

# croak on set where class can't be loaded
my $dying = AccessorGroups->new;
eval {
    $dying->result_class('Junkies');
};
ok($@ =~ /Could not load result_class 'Junkies'/);
is($dying->result_class, undef);

ok(!Class::Inspector->loaded('BaseInheritedGroups'));
AccessorGroups->result_class('BaseInheritedGroups');
ok(Class::Inspector->loaded('BaseInheritedGroups'));
is(AccessorGroups->result_class, 'BaseInheritedGroups');

## unset it
AccessorGroups->result_class(undef);
is(AccessorGroups->result_class, undef);