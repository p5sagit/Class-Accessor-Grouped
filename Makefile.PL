# $Id$
use strict;
use warnings;
use inc::Module::Install 1;

name 'Class-Accessor-Grouped';
license 'perl';
perl_version '5.006001';
all_from 'lib/Class/Accessor/Grouped.pm';

requires 'Carp';
requires 'Scalar::Util';
requires 'MRO::Compat';
requires 'Class::Inspector';
requires 'Sub::Name' => '0.04';

test_requires 'Test::More' => '0.94';
test_requires 'Test::Exception';

clean_files "Class-Accessor-Grouped-* t/var";

if (-e 'MANIFEST.SKIP') {
    system('pod2text lib/Class/Accessor/Grouped.pm > README');
    realclean_files 'README';
}

auto_install;

resources repository =>
'http://dev.catalyst.perl.org/repos/bast/Class-Accessor-Grouped/trunk';

WriteAll;
