use Test;
BEGIN { plan tests => 4 }
use WWW::Search::Pagesjaunes;

my $pj = WWW::Search::Pagesjaunes->new();
$pj->find( nom => "palais de l'elysée", localite => "paris");
my $r = $pj->results;

ok($r->name,    "Présidence de la République Palais de l'Elysée");
ok($r->address, "55 r Fbg St Honoré 75008 PARIS");
ok($r->phone,   "01 42 92 81 00");
ok($pj->has_more, 1);


