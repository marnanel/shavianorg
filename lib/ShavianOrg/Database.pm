package ShavianOrg::Database;

use strict;
use warnings;

use DBI;
use File::Slurp;
use Encode;

sub new {

  my ($class) = @_;

  my $filename = '/service/website/shavian.org.uk/conf/shaviandb.pl';

  die "$filename not found" unless -e $filename;

  my $result = eval(read_file($filename));

  $result->{'dbh'} = DBI->connect("dbi:Pg:host=localhost;db=$result->{name}",
    $result->{'user'},
    $result->{'pass'});

  die "Could not connect" unless $result->{'dbh'};

  return bless $result, $class;
}

sub dbh {
    my ($self) = @_;

    return $self->{'dbh'};
}

sub fetch {
    my ($self, $name, $namespace) = @_;

    my $sth = $self->{dbh}->prepare('select old_text from page, revision, pagecontent where page_namespace=? and page_latest=rev_id and rev_text_id=old_id and page_title=?');

    $sth->execute($namespace, $name);

    return $sth->fetchrow_array();
}

sub fetch_spelling {
    my ($self, $name) = @_;

    my $page = $self->fetch(ucfirst $name, 0);

    return undef unless $page;

    $page = Encode::decode('UTF-8', $page);
    my ($spelling) = $page =~ m/\{\{Shaw\|(.*?)\}\}/;

    # FIXME: Also handle per-alphabet lookup
    # (special cases, etc.)  This could be
    # useful elsewhere, though for the cases
    # we currently use this function for
    # it wouldn't be.

    return $spelling;
}

sub close {
    my ($self) = @_;

    $self->{'dbh'}->disconnect();
}

1;

