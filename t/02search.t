use Test;
BEGIN { plan tests => 5 }
use WWW::Search::Pagesjaunes;

my $pj = WWW::Search::Pagesjaunes->new();

$pj->{ua}->agent("test".time);

$pj->find( nom => "palais de l'elysée", localite => "paris");
my $r = $pj->results;

ok($r->name,    "Présidence de la République Palais de l'Elysée");
ok($r->address, "55 r Fbg St Honoré 75008 PARIS");
ok($r->phone->[0],   "01 42 92 81 00");
ok($pj->has_more, 1);


$pj->find( activite => "plombier", localite => "marseille", limit => 4);
my @r = $pj->results;
ok($#r, 3);


