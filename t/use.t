#!/usr/bin/env perl -w
use strict;
use Test;
BEGIN { plan tests => 1 }

use Lib::Module; ok(1);
use Lib::ModuleSymbol; ok(2);
exit;
__END__


