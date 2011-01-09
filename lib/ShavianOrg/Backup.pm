package ShavianOrg::Backup;

use strict;
use warnings;
use ShavianOrg::Database;
use JSON;

my %workspaces = (
  0 => 'main',
  1 => 'main-talk',
  2 => 'user',
  3 => 'user-talk',
  10 => 'shavian',
  11 => 'shavian-talk',
  100 => 'document',
  101 => 'document-talk',
);

# my $sth = $dbh->prepare('select page_namespace, page_title, old_text from page, revision, pagecontent where page_latest=rev_id and rev_text_id=old_id order by page_namespace, page_title');

sub handle {
  my $db = ShavianOrg::Database->new();
  my $dbh = $db->dbh();

  my $sth = $dbh->prepare('select page_namespace, page_title from page order by page_namespace, page_title');

  $sth->execute();

  for my $row (@{$sth->fetchall_arrayref()}) {
    my $filename;
    if (defined $workspaces{$row->[0]}) {
      $filename = $workspaces{$row->[0]};
    } else {
      $filename = $row->[0];
    }

    $filename = $filename . '/' . lcfirst substr($row->[1],0,1).'/'.lcfirst $row->[1].'.json';

    print "$filename\n";

    die "stop after one\n";
  }
}

1;

