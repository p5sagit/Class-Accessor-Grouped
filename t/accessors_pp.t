my $has_threads;
BEGIN { eval '
  use 5.008001;
  use threads;
  use threads::shared;
  $has_threads = 1;
' }

use strict;
use warnings;
no warnings 'once';
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

  my $pass = 1;
  share($pass) if $has_threads;

  my $todo = sub {
    note "\nTesting $tname without Sub::Name (pass @{[ $pass ++ ]})\n\n";

    my $tfn = catfile($Bin, $tname);

    delete $INC{$_} for (
      qw/AccessorGroups.pm AccessorGroupsRO.pm AccessorGroupsSubclass.pm AccessorGroupsParent.pm AccessorGroupsWO.pm/,
      File::Spec::Unix->catfile ($tfn),
    );

    local $SIG{__WARN__} = sub { warn @_ unless $_[0] =~ /subroutine .+ redefined/i };

    do($tfn);
  };

  if ($has_threads) {
    threads->create(sub {
      threads->create(sub {
        $todo->() for (1,2) }
      )->join;
      $todo->() for (1,2);
    })->join for (1,2)
  }
  else {
    $todo->() for (1, 2);
  }
}

done_testing;
