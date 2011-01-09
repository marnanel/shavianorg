package ShavianOrg::Index;

use strict;
use warnings;
use ShavianOrg::Database;

sub _fetch_initials {

    my ($db) = @_;

    my $dbh = $db->dbh();

    my $sth = $dbh->prepare('select distinct substring(page_title for 1) from page where page_namespace=100');

    $sth->execute();

    my @result;

    for my $letter (@{ $sth->fetchall_arrayref() }) {
        push @result, [ lc $letter->[0], $letter->[0] ];
    }

    @result = sort { $a->[0] cmp $b->[0] } @result;

    return { breadcrumbs => [], links => \@result };

}

sub _fetch_letter {
    my ($db, $letter) = @_;

    my $dbh = $db->dbh();

    my $sth = $dbh->prepare('select page_title from page where page_namespace=100 and page_title like ?');

    $sth->execute("$letter%%");

    my %titles;

    for my $letter (@{ $sth->fetchall_arrayref() }) {
        my $title = $letter->[0];

        $title =~ s/\/.*$//;
        $titles{$title}=1;
    }

    my @result;

    for my $title (sort keys %titles) {
        my $fixed_title = $title;
        $fixed_title =~ s/_/ /g;
        push @result, [ $title, $fixed_title ];
    }

    return { breadcrumbs => [[lc $letter, $letter]], links => \@result };
}

sub _fetch_prefix {
    my ($db, $title) = @_;

    my $id = 0;

    my $name = $title;
    $name =~ s/_/ /g;

    my $first = uc substr($title, 0, 1);

    my $dbh = $db->dbh();

    # Get the pages which are prefixed by this page name (plus a slash)

    my $sth = $dbh->prepare('select page_title from page where page_namespace=100 and page_title like ?');

    $sth->execute("$title/%%");

    my %titles;

    for my $letter (@{ $sth->fetchall_arrayref() }) {
        my $title = substr($letter->[0], length($title)+1);
        $title =~ s/\/.*$//;

        $titles{$title} = 1;
    }

    my @result;
    for my $subtitle (sort keys %titles) {
        push @result, ["$title/$subtitle", $subtitle];
    }

    # Also, look up the ID of this page
    # (and the page text, so that we can
    # get the titles into a reasonable order)

    $sth = $dbh->prepare('select old_text, old_id from page, revision, pagecontent where page_namespace=100 and page_latest=rev_id and rev_text_id=old_id and page_title=?');

    $sth->execute($title);

    my @found = $sth->fetchrow_array();
    
    if (@found) {
        $id = $found[1]*1;

        # Now re-sort the result list according to the text

        # ... FIXME
    }

    # All done!

    return { breadcrumbs => [[lc $first, $first], [$name, $title]],
        links => \@result,
        id => $id,
    };
}

sub fetch {
    my ($string) = @_;

    my $db = ShavianOrg::Database->new();

    if ($string eq '') {
        return _fetch_initials($db, '');
    } elsif ($string =~ /^.$/) {
        return _fetch_letter($db, uc $string);
    } else {
        return _fetch_prefix($db, $string);
    }
}

sub etag {
    my $db = ShavianOrg::Database->new();

    my $dbh = $db->dbh();

    my $sth = $dbh->prepare('select max(old_id) from pagecontent');
    $sth->execute();
    my ($tag) = $sth->fetchrow_array();

    return "W\"shaw$tag\"";
}

1;
