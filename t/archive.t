use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use DateTime;
use Comic;

__PACKAGE__->runtests() unless caller;


my $comic;
my $today;


sub set_up : Test(setup) {
    Comic::reset_statics();
    $today = DateTime->now;
}


sub makeComic {
    my ($title, $pubDate, $language) = @_;

    my %files;
    $files{"png"} = <<XML;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   xmlns="http://www.w3.org/2000/svg">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{
&quot;title&quot;: {
    &quot;$language&quot;: &quot;$title&quot;
},
&quot;tags&quot;: {
    &quot;$language&quot;: [&quot;Bier&quot;]
},
&quot;published&quot;: {
    &quot;when&quot;: &quot;$pubDate&quot;
}
}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g
     inkscape:groupmode="layer"
     id="layer2"
     inkscape:label="$language"
     style="display:inline"/>
</svg>
XML
    $files{"template"} = <<TEMPL;
[% FOREACH c IN comics %]
[% NEXT IF notFor(c, 'Deutsch') %]
<li><a href="[% c.href.Deutsch %]">[% c.meta_data.title.Deutsch %]</a></li>
[% END %]
[% modified %]
TEMPL
    
    *Comic::_slurp = sub {
        my ($file) = @_;
        return $files{$file};
    };
    *Comic::_mtime = sub {
        return 0;
    };
    *File::Path::make_path = sub {
        return 1;
    };
    *Comic::_now = sub {
        return $today;
    };

    return new Comic('png');
}


sub one_comic : Tests {
    my $wrote = "";
    local *Comic::_write_file = sub {
        my ($file, $contents) = @_;
        $wrote = $contents;
    };
    my %languages = ("Deutsch" => "template");
    my $comic = makeComic("Bier", "2016-01-01", 'Deutsch');
    Comic::export_archive(%languages);
    like($wrote, qr{<li><a href="comics/bier.html">Bier</a></li>}m);
}


sub some_comics : Tests {
    my $wrote = "";
    local *Comic::_write_file = sub {
        my ($file, $contents) = @_;
        $wrote = $contents;
    };
    my %languages = ("Deutsch" => "template");
    makeComic("eins", "2016-01-01", 'Deutsch');
    makeComic("zwei", "2016-01-02", 'Deutsch');
    makeComic("drei", "2016-01-03", 'Deutsch');
    Comic::export_archive(%languages);
    like($wrote, qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/zwei.html">zwei</a></li>\s+
        <li><a\shref="comics/drei.html">drei</a></li>\s+
    }mx);
}


sub ignores_if_not_that_language : Tests {
    my $wrote = "";
    local *Comic::_write_file = sub {
        my ($file, $contents) = @_;
        $wrote = $contents;
    };
    my %languages = ("Deutsch" => "template");
    makeComic("eins", "2016-01-01", 'Deutsch');
    makeComic("two", "2016-01-02", 'English');
    makeComic("drei", "2016-01-03", 'Deutsch');
    Comic::export_archive(%languages);
    like($wrote, qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/drei.html">drei</a></li>\s+
        }mx);
    ok($wrote !~ m/two/);
}


sub ignores_unpublished : Tests {
    my $wrote = "";
    local *Comic::_write_file = sub {
        my ($file, $contents) = @_;
        $wrote = $contents;
    };
    my %languages = ("Deutsch" => "template");
    $today = DateTime->new(year => 2016, month => 5, day => 1);
    makeComic('eins', "2016-01-01", 'Deutsch');
    makeComic('zwei', "2016-05-06", 'Deutsch');
    makeComic('drei', "2016-06-01", 'Deutsch');
    Comic::export_archive(%languages);
    like($wrote, qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/zwei.html">zwei</a></li>\s+
        }mx);
}


__END__
sub last_modified_from_archive_language : Test {
    my $wrote = "";
    local *Comic::_write_file = sub {
        my ($file, $contents) = @_;
        $wrote = $contents;
    };
    my %languages = ("Deutsch" => "template");
    makeComic("2016-01-01", 'Deutsch');
    makeComic("2016-01-02", 'Deutsch');
    makeComic("2016-01-03", 'English');
    Comic::export_archive(%languages);
    like($wrote, qr{2016-01-02}m);
}
