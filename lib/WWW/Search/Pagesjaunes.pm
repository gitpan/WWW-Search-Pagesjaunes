package WWW::Search::Pagesjaunes;

use strict;
use HTML::Form;
use HTML::TokeParser;
use LWP::UserAgent;

$WWW::Search::Pagesjaunes::VERSION = '0.01';

sub ROOT_URL() { 'http://www.pagesjaunes.fr' }

sub new {
    my $class = shift;
    my $self  = {};
    my $ua    = shift () || LWP::UserAgent->new(
        env_proxy  => 1,
        keep_alive => 1,
        timeout    => 30,
    );
    $ua->agent( "WWW::Search::Pagesjaunes/$WWW::Search::Pagesjaunes::VERSION " . $ua->agent );
    $self->{ua} = $ua;

    bless( $self, $class );
}

sub find {
    my $self = shift;
    my %opt  = @_;
    return undef unless $opt{localite} && ( $opt{activite} || $opt{nom} );
    $self->{URL} = ROOT_URL . ( $opt{activite} ? '/pj.cgi' : '/pb.cgi' );

    my $form = HTML::Form->parse(
        $self->{ua}->request( HTTP::Request->new( 'GET', $self->{URL} ) )
          ->content,
        $self->{URL}
    );

    $form->value( 'FRM_ACTIVITE', $opt{activite} ) if $opt{activite};
    $form->value( 'FRM_NOM',      $opt{nom} );
    $form->value( 'FRM_PRENOM',   $opt{prenom} )   if !$opt{activite};
    $form->value( 'FRM_ADRESSE',  $opt{adresse} );
    $form->value( 'FRM_LOCALITE', $opt{localite} );
    $form->value( 'FRM_DEPARTEMENT', $opt{departement} );

    $self->{limit} = $opt{limit} || 10;

    $self->{req} = $form->click;

    return $self;
}

sub results {
    my $self = shift;

    my $result_page = $self->{ua}->request( $self->{req} )->content;
    my $parser      = HTML::TokeParser->new( \$result_page );

    my @results;

	if ( $self->{limit} <= 0 ){
		$self->{has_more} = 0;
		return @results;
	}

    # XXX This is a really crude parsing of the data, but it seems to
    # get the job done.
    # 
    # <table class="fdcadreinscr">
    #   <table class="fdinscr">
    #     <tr class="fdrsinscr">
    #       <td class="txtrsinscr">Name</td>
    #     </tr>
    #     <tr valign="top">
    #       <td class="txtinscr">Address</td>
    #       <td align="right" class=txtinscr nowrap>(télécopie)? Phone</td>
    #     </tr>
    #   </table>
    # </table>
    # 
    $self->{has_more} = 0;

    while ( my $token = $parser->get_tag("table") ) {
        next
          unless $token->[1]
          && $token->[1]{class}
          && $token->[1]{class} eq 'fdcadreinscr';
        {    # We're inside an entry table

            $parser->get_tag("td");    # The first <td> is the name
            my $name = $parser->get_trimmed_text('/td');
            $name =~ s/^\W*|\W*$//g;

            $parser->get_tag("td");    # The second <td> is the address
            my $address = $parser->get_trimmed_text('/td');
            $address =~ s/\W*\|.*$//;
            $address =~ s/^\W*|\W*$//g;

            $parser->get_tag("td");    # The third <td> is the phone number
            my $phone = $parser->get_trimmed_text('/td');
            $phone =~ s/^\W*|\W*$//g;

			last if $self->{limit}-- == 0;

            push ( @results,
                WWW::Search::Pagesjaunes::Entry->new( $name, $address, $phone, 0 ) )
        }
    }


    foreach my $form ( HTML::Form->parse( $result_page, $self->{URL} ) ) {
        if (   $form->find_input('faire')
            && $form->value('faire') eq 'inscriptions_suivant' )
        {
            $self->{has_more} = 1;
            $self->{req}      = $form->click();
        }
    }
    wantarray ? @results : $results[0];
}

sub has_more { $_[0]->{has_more} }

package WWW::Search::Pagesjaunes::Entry;
sub new { bless [ $_[1], $_[2], $_[3], $_[4] ], $_[0] }
sub name    { $_[0]->[0] }
sub address { $_[0]->[1] }
sub phone   { $_[0]->[2] }
sub is_fax  { $_[0]->[3] }
sub entry   { join ( $_[1] || ' - ', @{ $_[0] }[ 0 .. 2 ] ) }

1;

__END__

=pod

=head1 NAME

WWW::Search::Pagesjaunes - Lookup phones numbers from www.pagesjaunes.fr

=head1 SYNOPSIS

 use WWW::Search::Pagesjaunes;

 my $pj = new WWW::Search::Pagesjaunes;
 $pj->find( activite => "Plombier", localite => "Paris" );

 {
    print $_->entry . "\n" foreach ($pj->results);
    redo if $pj->has_more;
 }

=head1 DESCRIPTION

The WWW::Search::Pagesjaunes provides name, phone number and addresses of French
telephone subscribers by using the L<http://www.pagesjaunes.fr>
directory.

=head1 METHODS

Two classes are used in this module, a first one (WWW::Search::Pagesjaunes) to do the
fetching and parsing, and the second one and a second one
(WWW::Search::Pagesjaunes::Entry) holding the entry infos.

Here are the methods for the main WWW::Search::Pagesjaunes module:

=over 4

=item new()

The constructor accept an optional LWP::UserAgent as argument, if you want to
provide your own.

=item find( %request )

Here are the values for the %request hash that are understood:

=over 4

=item nom

Name of the person you're looking for.

=item activite

Professional activity of the company you're looking for. Note that if this
field is filled, the module searches in the yellow pages.

=item localite

Name of the town you're searching in.

=item prenom

First name of the person you're looking for. It is not set if you set the
'activite' field.

=item departement

Name or number of the Département you're searching in.

=back

=item results()

Returns an array of WWW::Search::Pagesjaunes::Entry containing the first matches of the
query.

=item has_more()

If the query leads to more than a few results, the field has_more is set. You
can then call the results() method again to fetch the datas.

=back

The WWW::Search::Pagesjaunes::Entry class has four methods:

=over 4

=item new($name, $address, $phone, $fax)

Returns a new WWW::Search::Pagesjaunes::Entry.

=item name

Returns the name of the entry.

=item address

Returns the address of the entry.

=item phone

Returns the phone number of the entry.

=item is_fax

Returns true if the phone number is a fax one, false otherwise.

=item entry

Returns the concatenation of the name and the phone number, separated by " - ".

=back

=head1 BUGS

The phone numbers are sometimes not correctly parsed, esp. when one
entry has several phone numbers.

=head1 COPYRIGHT

Please read the Publisher information of L<http://www.pagesjaunes.fr> available at the following URL:
http://www.pagesjaunes.fr/pj.cgi?html=commun/avertissement.html&lang=en

WWW::Search::Pagesjaunes is Copyright (C) 2002, Briac Pilpré

This module is free software; you can redistribute it or modify it under the
same terms as Perl itself.

=head1 AUTHOR

Briac Pilpré L<briac@cpan.org>

=cut

