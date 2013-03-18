use strict;
use warnings;
use FindBin qw($Bin);
use File::Spec::Functions;
use File::Spec::Unix (); # need this for %INC munging
use Test::More;
use lib 't/lib';

BEGIN {
  local $ENV{DEVEL_HIDE_VERBOSE} = 0;
  eval { require Devel::Hide };
  if ($@) {
    eval { require Sub::Name };
    plan skip_all => "Devel::Hide required for this test in presence of Sub::Name"
      if ! $@;
  }
  else {
    Devel::Hide->import('Sub/Name.pm');
  }
  require Class::Accessor::Grouped;
}


# rerun the regular 3 tests under the assumption of no Sub::Name
our $SUBTESTING = 1;
for my $tname (qw/accessors.t accessors_ro.t accessors_wo.t/) {

  for (1,2) {
    note "\nTesting $tname without Sub::Name (pass $_)\n\n";

    my $tfn = catfile($Bin, $tname);

    delete $INC{$_} for (
      qw/AccessorGroups.pm AccessorGroupsRO.pm AccessorGroupsSubclass.pm AccessorGroupsParent.pm AccessorGroupsWO.pm/,
      File::Spec::Unix->catfile ($tfn),
    );

    local $SIG{__WARN__} = sub { warn @_ unless $_[0] =~ /subroutine .+ redefined/i };

    do($tfn);

  }
}

done_testing;
