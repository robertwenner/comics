use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


my $comic;


sub set_up : Test(setup) {
    Comic::reset_statics();
}


sub makeComic {
    my ($pubDate, $language) = @_;

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
    &quot;$language&quot;: &quot;$language trinken&quot;
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

    return new Comic('png');
}


sub one_comic : Tests {
    my $wrote = "";
    local *Comic::_write_file = sub {
        my ($file, $contents) = @_;
        $wrote = $contents;
    };
    my %languages = ("Deutsch" => "template");
    my $comic = makeComic("2016-01-01", 'Deutsch');
    Comic::export_archive(%languages);
    like($wrote, qr{<li><a href="comics/deutsch-trinken.html">Deutsch trinken</a></li>}m);
}


sub some_comics : Tests {
    my $wrote = "";
    local *Comic::_write_file = sub {
        my ($file, $contents) = @_;
        $wrote = $contents;
    };
    my %languages = ("Deutsch" => "template");
    makeComic("2016-01-01", 'Deutsch');
    makeComic("2016-01-02", 'Deutsch');
    makeComic("2016-01-03", 'Deutsch');
    Comic::export_archive(%languages);
    like($wrote, qr{(<li><a href="comics/deutsch-trinken.html">Deutsch trinken</a></li>\s*){3}}m);
}


sub ignores_if_not_that_language : Tests {
    my $wrote = "";
    local *Comic::_write_file = sub {
        my ($file, $contents) = @_;
        $wrote = $contents;
    };
    my %languages = ("Deutsch" => "template");
    makeComic("2016-01-01", 'Deutsch');
    makeComic("2016-01-02", 'English');
    makeComic("2016-01-03", 'Deutsch');
    Comic::export_archive(%languages);
    like($wrote, qr{(<li><a href="comics/deutsch-trinken.html">Deutsch trinken</a></li>\s*){2}}m);
    ok($wrote !~ m/English/);
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
