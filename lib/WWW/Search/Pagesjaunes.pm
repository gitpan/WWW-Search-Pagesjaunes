package WWW::Search::Pagesjaunes;
use strict;
use Carp qw(carp croak);
use HTML::Form;
use HTML::TokeParser;
use LWP::UserAgent;

$WWW::Search::Pagesjaunes::VERSION = '0.08';

sub ROOT_URL() { 'http://www.pagesjaunes.fr' }

sub new {
    my $class = shift;
    my $self  = {};
    my $ua    = shift() || LWP::UserAgent->new(
        env_proxy  => 1,
        keep_alive => 1,
        timeout    => 30,
    );

    $ua->agent( "WWW::Search::Pagesjaunes-X/$WWW::Search::Pagesjaunes::VERSION "
          . $ua->agent );

    $self->{ua}    = $ua;
    $self->{limit} = 50;

    $self->{error} = 1;
    $self->{lang}  = 'FR';

    bless( $self, $class );
}

sub find {
    my $self = shift;
    my %opt  = @_;

    # Make the first request to pagesjaunes.fr
    $self->{URL} = ROOT_URL . ( $opt{activite} ? '/pj.cgi' : '/pb.cgi' );

    my $req = $self->{ua}->request( HTTP::Request->new( 'GET', $self->{URL} ) );

    $DB::single = 1;
    if ( !$req->content || !$req->is_success ) {
        croak('Error while retrieving the HTML page');
    }

    my @forms = HTML::Form->parse( $req->content, $self->{URL} );

    #my $form = $opt{activite} ? $forms[1] : $forms[0];
    my $form = $forms[0];

    {

        # HTML::Form complains when you change hidden fields values.
        local $^W;
        $form->value( 'lang', $self->{lang} );
    }

    $form->value( 'FRM_ACTIVITE', $opt{activite} ) if $opt{activite};
    $form->value( 'FRM_NOM',      $opt{nom} );
    $form->value( 'FRM_PRENOM',   $opt{prenom} )   if !$opt{activite};
    $form->value( 'FRM_ADRESSE',  $opt{adresse} );
    $form->value( 'FRM_LOCALITE', $opt{localite} );
    $form->value( 'FRM_DEPARTEMENT', $opt{departement} );

    $self->{limit} = $opt{limit} || $self->{limit};

    $self->{req} = $form->click;

    return $self;
}

sub results {
    my $self = shift;

    my $result_page = $self->{ua}->request( $self->{req} )->content;
    my $parser      = HTML::TokeParser->new( \$result_page );

    # All the <br> tags are transformed to whitespace
    $parser->{textify} = {
        'br' => sub() { " " }
    };

    my @results;

    if ( $self->{limit} == 0 ) {
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
    #       <td class="txtrsinscr" align=right>&nbsp;</td>
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
            my $name = _trim( $parser->get_trimmed_text('/td') );

            $parser->get_tag("td");    # The second <td> is the address
            my $address = _trim( $parser->get_trimmed_text('/td') );
            $address =~ s/\W*\|.*$//;

            $parser->get_tag("td");    # The third <td> is the phone number
            my $phone = _trim( $parser->get_trimmed_text('/td') );
            $phone =~ s/^\W(.*)$/$1/g;

            push(
                @results,
                WWW::Search::Pagesjaunes::Entry->new(
                    $name, $address, $phone, 0
                )
            );

            return @results if --$self->{limit} == 0;
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

    # If there was no result, we look for an error message in the HTML page
    if ( !@results && $self->{error} ) {
        $parser = HTML::TokeParser->new( \$result_page );
        while ( my $token = $parser->get_tag("font") ) {
            next
              unless $token->[1]
              && $token->[1]{color}
              && $token->[1]{color} eq '#ff0000';
            $parser->{textify} = {
                'br' => sub() { " " }
            };
            print STDERR _trim( $parser->get_trimmed_text('/font') ) . "\n";
        }
    }

    wantarray ? @results : $results[0];
}

sub _trim {
    $_[0] =~ s/\xa0/ /g;       # Transform the &nbsp; into whitespace
    $_[0] =~ s/^\s*|\s*$//g;
    $_[0];
}

sub limit {
    my $self = shift;
    $self->{limit} = $_[0] || $self->{limit};
}

sub has_more { $_[0]->{has_more} }

package WWW::Search::Pagesjaunes::Entry;
sub new { bless [ $_[1], $_[2], $_[3], $_[4] ], $_[0] }
sub name    { $_[0]->[0] }
sub address { $_[0]->[1] }
sub phone   { $_[0]->[2] }
sub is_fax  { $_[0]->[3] }
sub entry   { @{ $_[0] }[ 0 .. 2 ] }

1;

__END__

=pod

=head1 NAME

WWW::Search::Pagesjaunes - Lookup phones numbers from www.pagesjaunes.fr

=head1 SYNOPSIS

 use WWW::Search::Pagesjaunes;

 my $pj = new WWW::Search::Pagesjaunes;
 $pj->find( activite => "Plombier", localite => "Paris" );

 do {
    print $_->entry . "\n" foreach ($pj->results);
 } while $pj->has_more;

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

Here are the values for the %request hash that are understood. They
each have two name, the first is the french one and the second is the
english one:

=over 4

=item nom / name

Name of the person you're looking for.

=item activite / business

Business type of the company you're looking for. Note that if this
field is filled, the module searches in the yellow pages.

=item localite / town

Name of the town you're searching in.

=item prenom / firstname

First name of the person you're looking for. It is not set if you set the
'activite' field.

=item departement / district

Name or number of the Département or Région you're searching in.

=back

=item results()

Returns an array of WWW::Search::Pagesjaunes::Entry containing the first matches of the
query.

=item limit($max_number_of_entries)

Set the maximum number of entries returned. Default to 50.

=item has_more()

If the query leads to more than a few results, the field has_more is set. You
can then call the results() method again to fetch the datas.

=back

The WWW::Search::Pagesjaunes::Entry class has six methods:

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

Returns true if the phone number is a fax one, false otherwise. Note
that currently, this method always returns 0.

=item entry($separator)

Returns the concatenation of the name and the phone number, separated by
" - ". You can specify your own separator as first argument.

=back

=head1 BUGS

The phone numbers are sometimes not correctly parsed, esp. when one
entry has several phone numbers.

If you found a bug and want to report it or send a patch, you are
encouraged to use the CPAN Request Tracker interface:
L<https://rt.cpan.org/NoAuth/Dists.html?Queue=WWW-Search-Pagesjaunes>

=head1 COPYRIGHT

Please read the Publisher information of L<http://www.pagesjaunes.fr> available at the following URL:
L<http://www.pagesjaunes.fr/pj.cgi?html=commun/avertissement.html&lang=en>

WWW::Search::Pagesjaunes is Copyright (C) 2002, Briac Pilpré

This module is free software; you can redistribute it or modify it under the
same terms as Perl itself.

=head1 AUTHOR

Briac Pilpré <briac@cpan.org>

=cut


