use strict;
use warnings;
use Test::More;
BEGIN {
  eval 'use Test::Pod 1.00; 1'
    or plan skip_all => 'Test::Pod 1.00 not installed';
}

all_pod_files_ok();
