use Test;
BEGIN { plan tests => 5 }
use WWW::Search::Pagesjaunes;

my $pj = WWW::Search::Pagesjaunes->new();

$pj->{ua}->agent("test".time);

$pj->find( nom => "palais de l'elys�e", localite => "paris");
my $r = $pj->results;

ok($r->name,    "Pr�sidence de la R�publique Palais de l'Elys�e");
ok($r->address, "55 r Fbg St Honor� 75008 PARIS");
ok($r->phone->[0],   "01 42 92 81 00");
ok($pj->has_more, 1);


$pj->find( activite => "plombier", localite => "marseille", limit => 4);
my @r = $pj->results;
ok($#r, 3);


