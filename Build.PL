#!/usr/bin/perl
use warnings;
use strict;
use Module::Build;

Module::Build->new(
    module_name => 'Class::Accessor::Grouped',
    dist_author => [
        'Matt S. Trout <mst@shadowcatsystems.co.uk>',
        'Christopher H. Laco <claco@chrislaco.com>'
    ],
    license => 'perl',
    requires => {
        'Carp' => 0,
        'Scalar::Util' => 0,
        'Class::ISA' => 0
    },
    create_makefile_pl => 'passthrough',
    create_readme => 1,
)->create_build_script;
