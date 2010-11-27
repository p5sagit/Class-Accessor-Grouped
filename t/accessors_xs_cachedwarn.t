use strict;
use warnings;
use FindBin qw($Bin);
use File::Spec::Functions;
use File::Spec::Unix (); # need this for %INC munging
use Test::More;
use lib 't/lib';

BEGIN {
    require Class::Accessor::Grouped;
    my $xsa_ver = $Class::Accessor::Grouped::__minimum_xsa_version;
    eval {
        require Class::XSAccessor;
        Class::XSAccessor->VERSION ($xsa_ver);
    };
    plan skip_all => "Class::XSAccessor >= $xsa_ver not available"
      if $@;
}

use AccessorGroupsSubclass;
$Class::Accessor::Grouped::USE_XS = 1;

my $obj = AccessorGroupsSubclass->new;
my $deferred_stub = AccessorGroupsSubclass->can('singlefield');

my @w;
{
  local $SIG{__WARN__} = sub { push @w, @_ };
  is ($obj->$deferred_stub(1), 1, 'Set');
  is ($obj->$deferred_stub, 1, 'Get');
  is ($obj->$deferred_stub(2), 2, 'ReSet');
  is ($obj->$deferred_stub, 2, 'ReGet');
}

is (
  scalar (grep { $_ =~ /^\QDeferred version of method AccessorGroups::singlefield invoked more than once/ } @w),
  3,
  '3 warnings produced as expected on cached invocation during testing',
);

done_testing;
