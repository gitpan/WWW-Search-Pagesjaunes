use Test;
BEGIN { plan tests => 1 }
END   { ok($loaded) }
use WWW::Search::Pagesjaunes;
$loaded++;
