# $Id$
use strict;
use warnings;
use inc::Module::Install 0.65;

name 'Class-Accessor-Grouped';
license 'perl';
perl_version '5.006001';
all_from 'lib/Class/Accessor/Grouped.pm';

requires 'Carp';
requires 'Scalar::Util';
requires 'MRO::Compat';
requires 'Class::Inspector';
requires 'Sub::Name' => '0.04';

feature 'XS Accessor Support',
  -default => 0,
  'Class::XSAccessor' => 0;


test_requires 'Sub::Identify';

clean_files "Class-Accessor-Grouped-* t/var";

auto_install;

WriteMakefile(
  dist => {
    PREOP => 'pod2text lib/Class/Accessor/Grouped.pm > README'
  }
);
