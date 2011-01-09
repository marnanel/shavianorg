package ShavianOrg;

use strict;
use warnings;

use ShavianOrg::Render;
use ShavianOrg::Skin;
use ShavianOrg::Index;

sub _redirect {
    my ($url) = @_;
    $url = "http://shavian.org/read/$url";
    print "Status: 301 Moved\n";
    print "Content-Type: text/plain\n";
    print "Content-Length: ".(length($url)+1)."\n";
    print "Location: $url\n\n$url\n";
    return '';
}

sub _unmodified {
    print "Status: 304 Unmodified\n\n";
    return '';
}

sub handle {

    my $path = $ENV{'PATH_INFO'};
    $path = '' unless defined $path;
    $path =~ s/^\///;

    #return _redirect("$path/") unless $path =~ /\/$/;

    my $old_etag = $ENV{'HTTP_IF_NONE_MATCH'};
    my $etag = ShavianOrg::Index::etag();
    return _unmodified() if defined $old_etag && $etag eq $old_etag;
    print "ETag: $etag\n";

    print "Content-Type: text/html\n\n";

    my $content = ShavianOrg::Index::fetch($path);

    if (!@{$content->{'links'}} && defined $content->{'id'}) {
        my $breadcrumbs = $content->{'breadcrumbs'};
        $content = ShavianOrg::Render::render($content->{'id'});
        $content->{'breadcrumbs'} = $breadcrumbs;
    }

    ShavianOrg::Skin::handle($content);
}

1;

