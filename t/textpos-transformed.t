use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub before : Test(setup) {
    MockComic::set_up();
}


sub assert_order {
    my ($svg, $expected) = @_;
    my $comic = MockComic::make_comic($MockComic::XML => $svg);
    my $is = join "", $comic->texts_in_language('English');
    is($is, $expected);
}



sub simple_texts : Tests {
    assert_order(<<'SVG', "123");
  <g inkscape:groupmode="layer" inkscape:label="English">
    <text x="327" y="1085.3622">
        <tspan>2</tspan>
    </text>
    <text x="6" y="828.36218">
        <tspan>1</tspan>
    </text>
    <text x="582.62695" y="1082.1501">
        <tspan>3</tspan>
    </text>
  </g>
SVG
}


sub rotated_text : Tests {
    assert_order(<<'SVG', "IntroSpeak1Meta1Rotate1Meta2Speak2Meta3Speak3Meta4Rotate4");
  <g inkscape:groupmode="layer" inkscape:label="English">
    <text x="329.48169" y="806.60828" transform="rotate(17.251546)">
      <tspan>Rotate1</tspan>
    </text>
    <text x="209.64128" y="826.38843">
      <tspan>Speak2</tspan>
    </text>
    <text x="704.39362" y="683.81781" transform="rotate(17.251546)">
      <tspan>Rotate4</tspan>
    </text>
    <text x="5.8287659" y="823.57593">
      <tspan>Speak1</tspan>
    </text>
    <text x="415.42969" y="826.74243">
      <tspan>Speak3</tspan>
    </text>
  </g>
  <g inkscape:groupmode="layer" inkscape:label="MetaEnglish">
    <text x="-48" y="786.36218">
      <tspan>Intro</tspan>
    </text>
    <text x="18.684189" y="892.88269">
      <tspan>Meta1</tspan>
    </text>
    <text x="428.65439" y="899.23718">
      <tspan>Meta4</tspan>
    </text>
    <text x="381.65439" y="826.23718">
      <tspan>Meta3</tspan>
    </text>
    <text x="191.65439" y="839.23718">
      <tspan>Meta2</tspan></text>
  </g>
SVG
}

__END__

# Maybe http://search.cpan.org/~colink/SVG-Estimate-1.0107/ would help?
# Unfortunately, it does not pass its tests and does not install :-(

# Then I could get the dimensions of the text (maybe, SVG::Estimate does not
# mention it supports text, even though it supports lots of other shapes and
# things), and subtract the x length from the x coordinate.

sub right_aligned_texts : Tests {
    assert_order(<<'SVG', "123");
  <g inkscape:groupmode="layer" inkscape:label="English">
    <text x="10" y="0">
        <tspan x="10" y="0">1</tspan>
    </text>
    <text x="30" y="0">
        <tspan x="30" y="0">3</tspan>
    </text>
    <text x="40" y="0" style="text-align:end;">
        <tspan x="40" y="0">2</tspan>
    </text>
  </g>
SVG
}


__END__
# With SVG::Estimate, I could copy path and text node to a new document and
# then get its size. But does that tell me where in the old one it is
# located?

sub text_on_path_simple : Tests {
    my $svg = <<'SVG';
    <text x="-20" y="-15">
      <textPath xlink:href="#dreieck">text</textPath>
    </text>
    <path d="M 100 100 L 300 100 L 200 300 z" id="dreieck"/>
SVG
    my $comic = MockComic::make_comic($MockComic::XML => $svg);
    # this fucking sucks if I need to write code for each possible path and shape
    # for the off-chance I might actually eventually use it.
    my @texts = $comic->{xpath}->findnodes(Comic::_build_xpath('text'));
    my ($x, $y) = $comic->_transformed($texts[0]);
    is($x, '...', 'wrong x');
    is($y, '...', 'wrong y');
}

__END__


sub text_on_path_ellipse : Tests {
    my $svg = <<'SVG';
    <text x="-20" y="-15">
      <textPath xlink:href="#path">text</textPath>
    </text>
    <ellipse id="path" cx="267.1633" cy="932.95453" rx="34.891293" ry="38.88921"/>
SVG
    my $comic = MockComic::make_comic($MockComic::XML => $svg);
    my @texts = $comic->{xpath}->findnodes(Comic::_build_xpath('text'));
    my ($x, $y) = $comic->_transformed($texts[0]);
    is($x, 100, 'wrong x');
    is($y, 100, 'wrong y');
}


__END__
sub text_on_path_tspan_with_dx : Tests {
    ok(0, 'write me');
}


start with the text coordintates
    what if the text does not have any? use the path?
apply transform on linked path
ignore a transform on a g element enclosing the text


textPath attributes:
startOffest (default 0, can be % (0 start, 100 end), or user coordinate system

can probably ignore font size, startOffset and such cause in my comics I won't
have overlapping text. left most (smallest) x is fine, as is y for that x.



__END__
sub text_on_path_real_world : Tests {
    assert_order(<<'SVG', "Intro:Title:I can drink it!All by myself!");
  <g inkscape:groupmode="layer" inkscape:label="MetaEnglish">
    <text x="-42.23204" y="861.86578">
      <tspan>Intro:</tspan>
    </text>
  </g>
  <g inkscape:groupmode="layer" inkscape:label="English">
    <text x="-83.029472" y="1017.0272" transform="rotate(-5.6931704)">
      <tspan>Title:</tspan>
    </text>
    <text x="-2.1428571" y="-15">
      <textPath xlink:href="#path3887">
        <tspan dx="80.812202">I can drink it!</tspan>
      </textPath>
    </text>
    <g id="g3426" transform="rotate(180,320.57846,970.1288)">
      <ellipse ry="38.88921" rx="34.891293" cy="1007.3622" cx="373.91425" id="path3887-6"/>
      <text>
         <textPath xlink:href="#path3887-6">
           <tspan dx="71.785721 0 0 -3.5714285">All by myself!</tspan>
         </textPath>
      </text>
    </g>
  </g>
  <g inkscape:groupmode="layer" inkscape:label="Figuren">
    <ellipse id="path3887" cx="267.1633" cy="932.95453" rx="34.891293" ry="38.88921"/>
  </g>
SVG
}
