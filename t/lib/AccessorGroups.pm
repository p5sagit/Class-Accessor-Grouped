package AccessorGroups;
use strict;
use warnings;
use base 'Class::Accessor::Grouped';

__PACKAGE__->mk_group_accessors('simple', 'singlefield');
__PACKAGE__->mk_group_accessors('multiple', qw/multiple1 multiple2/);
__PACKAGE__->mk_group_accessors('listref', [qw/lr1name lr1;field/], [qw/lr2name lr2'field/]);

sub get_simple {
  my $v = shift->SUPER::get_simple (@_);
  $v =~ s/ Extra tackled on$// if $v;
  $v;
}

sub set_simple {
  my ($self, $f, $v) = @_;
  $v .= ' Extra tackled on' if $f eq 'singlefield';
  $self->SUPER::set_simple ($f, $v);
  $_[2];
}

sub new {
    return bless {}, shift;
};

foreach (qw/multiple listref/) {
    no strict 'refs';
    *{"get_$_"} = __PACKAGE__->can('get_simple');
    *{"set_$_"} = __PACKAGE__->can('set_simple');
};

1;
