use strictures 1;

BEGIN {
  my @missing;
  for (qw/
    Class::Accessor::Grouped
    Class::XSAccessor
    Class::Accessor::Fast
    Class::Accessor::Fast::XS
    Moose
    Mouse
  /) {
    eval "require $_" or push @missing, $_;
  }

  if (@missing) {
    die sprintf "Missing modules necessary for benchmark:\n\n%s\n\n",
      join ("\n", @missing);
  }
}


use Benchmark qw/:hireswallclock cmpthese/;

{
  package Bench::Accessor;

  use strictures 1;

  our @ISA;

  use base qw/Class::Accessor::Grouped Class::Accessor::Fast/;
  use Class::XSAccessor { accessors => [ 'xsa' ] };

  {
    local $Class::Accessor::Grouped::USE_XS = 0;
    __PACKAGE__->mk_group_accessors ('simple', 'cag');
  }
  {
    local $Class::Accessor::Grouped::USE_XS = 1;
    __PACKAGE__->mk_group_accessors ('simple', 'cag_xs');
  }
  __PACKAGE__->mk_accessors('caf');

  {
    require Class::Accessor::Fast::XS;
    local @ISA = 'Class::Accessor::Fast::XS';
    __PACKAGE__->mk_accessors ('caf_xs');
  }

  sub handmade {
    @_ > 1 ? $_[0]->{handmade} = $_[1] : $_[0]->{handmade};
  }

}
my $bench_objs = {
  base => bless ({}, 'Bench::Accessor')
};

sub _add_moose_task {
  my ($tasks, $name, $class) = @_;
  my $meth = lc($name);

  my $gen_class = "Bench::Accessor::$class";
  eval <<"EOC";
package $gen_class;
use $class;
has $meth => (is => 'rw');
__PACKAGE__->meta->make_immutable;
EOC

  $bench_objs->{$name} = $gen_class->new;
  _add_task ($tasks, $name, $meth, $name);
}

sub _add_task {
  my ($tasks, $name, $meth, $slot) = @_;

  $tasks->{$name} = eval "sub {
    for (my \$i = 0; \$i < 100; \$i++) {
      \$bench_objs->{$slot}->$meth(1);
      \$bench_objs->{$slot}->$meth(\$bench_objs->{$slot}->$meth + 1);
    }
  }";
}

my $tasks = {
#  'direct' => sub {
#    $bench_objs->{base}{direct} = 1;
#    $bench_objs->{base}{direct} = $bench_objs->{base}{direct} + 1;
#  }
};

for (qw/CAG CAG_XS CAF CAF_XS XSA HANDMADE/) {
  _add_task ($tasks, $_, lc($_), 'base');
}

my $moose_based = {
  moOse => 'Moose',
  ($ENV{MOUSE_PUREPERL} ? 'moUse' : 'moUse_XS') => 'Mouse',
};
for (keys %$moose_based) {
  _add_moose_task ($tasks, $_, $moose_based->{$_})
}


for (1, 2) {
  print "Perl $], take $_:\n";
  cmpthese ( -1, $tasks );
  print "\n";
}
