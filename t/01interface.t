use Test;
BEGIN { plan tests => 1 }
use WWW::Search::Pagesjaunes;

my $pj = WWW::Search::Pagesjaunes->new();
ok(ref($pj), 'WWW::Search::Pagesjaunes');

