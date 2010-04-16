use strict;
use warnings;
use inc::Module::Install;

all_from 'lib/Text/Xslate.pm';

use_ppport 3.19;
cc_warnings;

requires 'Mouse'                => '0.53';
requires 'MouseX::NativeTraits' => '0.002';

test_requires 'Test::More' => 0.88; # done_testing()

tests_recursive 't';

cc_src_paths qw(xs);

auto_set_repository() if -d '.git';

clean_files qw(
    Text-Xslate-* *.stackdump
    *.gcda *.gcno *.gcov
    nytprof *.out
    cover_db
);

WriteAll(check_nmake => 0);

