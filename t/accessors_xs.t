use strict;
use warnings;
use FindBin qw($Bin);
use File::Spec::Functions;
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

# rerun all 3 tests under XSAccessor
$Class::Accessor::Grouped::USE_XS = 1;
for (qw/accessors.t accessors_ro.t accessors_wo.t/) {
  subtest "$_ with USE_XS" => sub { require( catfile($Bin, $_) ) }
}

done_testing;
