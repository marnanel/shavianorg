package ShavianOrg::Render;

# Problems:
#   - Some stylesheet issue is adding extra space between paras (actually it's having P inside DIV)
#   - Need a check for a "wall" message (eg "system is down")
#   - Dialogues should close on Esc
#   - Dab highlights word, which is good, but highlights even when word is missing, e.g. "produce"
#   - Need to give address of document in URL
use strict;
use warnings;

use ShavianOrg::Database;
use ShavianOrg::Suggestions;
use JSON;

sub _render_latn {
    my ($document) = @_;

    my $db = ShavianOrg::Database->new();

    my $dbh = $db->dbh();

    my $sth = $dbh->prepare('select latn, suffix from triangledocs where docid=?');

    $sth->execute($document);

    my @result = ('');

    for my $word (@{ $sth->fetchall_arrayref() }) {
        $result[-1] .= $word->[0] if $word->[0];
        if ($word->[1]) {
            my ($before, $after) = $word->[1] =~ m/^(.*)\n\n(.*)$/;

            if (defined $after) {
                # there is a paragraph break
                $result[-1] .= $before if $before;
                push @result, '';
                $result[-1] .= $after if $after;
            } else {
                # no paragraph break
                $result[-1] .= $word->[1];
            }
        }
    }

    return \@result;
}

# Returns a listref of hashrefs.  Each one contains at least two fields, "type" and "value".
# *** The following is out of date ***
# If type is "f" (filler), the value is a literal string such as a space.
# If type is "s", the value is a Shavian string.
# If type is "u", the value is the Latin-alphabet string because the word was unknown.
# If type is "d", the word was ambiguous, the value is the word, and there is an extra field "d", a hash of possibilities.
sub render {
    my ($document, $debug) = @_;

    my $suggest = new ShavianOrg::Suggestions();

    my $db = new ShavianOrg::Database();
    my $dbh = $db->dbh();
    my $sth = $dbh->prepare('select suffix, latn, lemma, old_text from triangledocs left outer join page on lemma=page_title left outer join revision on page_latest=rev_id left outer join pagecontent on rev_text_id=old_id where docid=? and (page_namespace=0 or page_namespace is null)');

    my %footers;

    $sth->execute($document);

    my @result = ([]);
    my $count = 0;

    my @words = @{ $sth->fetchall_arrayref() };
    for (my $i=0; $i<scalar(@words); $i++) {

        my $word = $words[$i];
        $count++;

        if ($word->[1]) {
            if (!defined $word->[3]) {
                push @{$result[-1]}, { type=>'u', latn=>$word->[1], count=>$count };

                my $suggestions = $suggest->handle($word->[1]);

                if ($suggestions) {
                    $footers{$word->[1]} = {
                        suggest => $suggestions->[0],
                        source => $suggestions->[1],
                    };
                }
            } elsif ($word->[3] =~ /{{dab}}/i) {
                my %dabs = $word->[3] =~ m/^\*\s*\[\[([a-z_]*)\]\][ -]*([a-z0-9_ -]*)/mig;
                push @{$result[-1]}, { type=>'d', d => \%dabs, latn=>$word->[1], count=>$count };

                my @context = ([], []);

                for (my $j=$i-3; $j<$i+3; $j++) {
                    next unless defined $words[$j];
                    if ($j<$i) {
                        push @{$context[0]}, $words[$j]->[1];
                    } elsif ($j>$i) {
                        push @{$context[1]}, $words[$j]->[1];
                    }
                }

                my @dabs;
                my $start = length($word->[1])+1;
                for my $k (sort keys %dabs) {
                    push @dabs, substr($k, $start);
                    push @dabs, $dabs{$k};
                }

                $footers{$count} = { dab => \@dabs,
                        context=>[
                        join(' ',@{$context[0]}),
                        join(' ',@{$context[1]}),
                        ] };
            } else {
                my ($abbrev) = $word->[3] =~ m/{{Abbreviation\|Shaw\|([^|}]*)}}/i;
                my ($shaw) = $word->[3] =~ m/{{Shaw\|([^|}]*)/i;
                if (defined $abbrev) {
                    push @{$result[-1]}, { type=>'s', shaw=>$abbrev, latn=>$word->[1] };
                } elsif (defined $shaw) {
                    push @{$result[-1]}, { type=>'s', shaw=>$shaw, latn=>$word->[1] };
                } else {
                    # weird; fall back
                    push @{$result[-1]}, { type=>'u', latn=>$word->[1], count=>$count };
                }
            }
        }

        # Suffix?
        if ($word->[0]) {
            my $suffix = $word->[0];

            # I suppose we might have two, but it would be rare
            # and make the code far more complicated, and it doesn't
            # really cause any difficulties to ignore that case.

            my ($before, $after) = $suffix =~ m/^(.*)\n\n(.*)/;

            if (defined $after) {
                # there is a paragraph break
                push @{$result[-1]}, { type=>'f', value=>$before } if $before;
                push @result, [];
                push @{$result[-1]}, { type=>'f', value=>$after } if $after;
            } else {
                # there is no paragraph break
                push @{$result[-1]}, { type=>'f', value=>$suffix };
            }
        }
    }

    return {
        paras=>\@result,
        headers=>'<script type="text/javascript" src="/static/reading.js">'.
                '</script>'.
                '<link rel="stylesheet" href="/static/reading.css" />',
        footers=>"<script type=\"text/javascript\">\nvar wordDetails = ".
                to_json(\%footers, {utf8=>1, pretty=>1}).
                ";\n</script>\n",
        gcontrol=>1, # include ajax controls
        jscrib=>1, # include gubbins to allow Shavian typing
        };
}

1;
