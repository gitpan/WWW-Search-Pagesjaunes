use Test;
BEGIN { plan tests => 3 }
use WWW::Search::Pagesjaunes;

my $pj = WWW::Search::Pagesjaunes->new();
ok(ref($pj), 'WWW::Search::Pagesjaunes');

ok($pj->limit, 50);

$pj->limit(100);
ok($pj->limit, 100);

