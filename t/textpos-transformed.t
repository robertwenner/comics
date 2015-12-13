use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


my $comic;


sub setUp : Test(setup) {
    *Comic::_slurp = sub {
        my $xml = <<XML;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:xlink="http://www.w3.org/1999/xlink"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape">
   <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work>
        <dc:description>{}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g
     inkscape:groupmode="layer"
     id="layer4"
     inkscape:label="English"
     style="display:inline">
    <text
       xml:space="preserve"
       style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-size:59.67029572px;line-height:125%;font-family:'Domestic Manners';-inkscape-font-specification:'Domestic Manners';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       x="-41.729549"
       y="939.34296"
       id="text3675"
       sodipodi:linespacing="125%"
       transform="matrix(0.9950674,-0.09920114,0.09920114,0.9950674,0,0)"><tspan
         sodipodi:role="line"
         id="tspan3677"
         x="-41.729549"
         y="939.34296"
         style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-size:59.67000198px;line-height:125%;font-family:Duality;-inkscape-font-specification:'Duality, Normal';text-align:start;writing-mode:lr-tb;text-anchor:start">HOPS</tspan></text>
    <text
       xml:space="preserve"
       style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-size:25px;line-height:125%;font-family:'Domestic Manners';-inkscape-font-specification:'Domestic Manners';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       x="4.7198009"
       y="963.70673"
       id="text3681"
       sodipodi:linespacing="125%"
       transform="matrix(0.9950674,-0.09920114,0.09920114,0.9950674,0,0)"><tspan
         sodipodi:role="line"
         id="tspan3683"
         x="4.7198009"
         y="963.70673"
         style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-size:25px;line-height:125%;font-family:Duality;-inkscape-font-specification:'Duality, Normal';text-align:start;writing-mode:lr-tb;text-anchor:start">ON</tspan></text>
    <text
       xml:space="preserve"
       style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-size:62.87652588px;line-height:125%;font-family:'Domestic Manners';-inkscape-font-specification:'Domestic Manners';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       x="-83.029472"
       y="1017.0272"
       id="text3685"
       sodipodi:linespacing="125%"
       transform="matrix(0.9950674,-0.09920114,0.09920114,0.9950674,0,0)"><tspan
         sodipodi:role="line"
         x="-83.029472"
         y="1017.0272"
         id="tspan3693"
         style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-size:62.87652588px;line-height:125%;font-family:Duality;-inkscape-font-specification:'Duality, Normal';text-align:start;writing-mode:lr-tb;text-anchor:start">DRUNKS</tspan></text>
    <text
       xml:space="preserve"
       style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-size:20.88526535px;line-height:125%;font-family:'Domestic Manners';-inkscape-font-specification:'Domestic Manners';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       x="71.185287"
       y="1345.9312"
       id="text3689"
       sodipodi:linespacing="125%"
       transform="scale(1.1102167,0.90072502)"><tspan
         sodipodi:role="line"
         id="tspan3691"
         x="71.185287"
         y="1345.9312"
         style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;font-size:41.7705307px;font-family:RW;-inkscape-font-specification:'RW Medium'">by Dr. Suds</tspan></text>
    <text
       xml:space="preserve"
       style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;font-size:26.08291245px;line-height:100%;font-family:RW;-inkscape-font-specification:'RW Medium';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       x="-475.836"
       y="1008.2883"
       id="text3574"
       sodipodi:linespacing="100%"
       transform="matrix(0.88965877,-0.50068284,0.5450047,0.8173083,0,0)"><tspan
         sodipodi:role="line"
         id="tspan3576"
         x="-475.836"
         y="1008.2883"
         style="line-height:100%">Imp</tspan><tspan
         sodipodi:role="line"
         x="-475.836"
         y="1034.3712"
         style="line-height:100%"
         id="tspan3580">IPA</tspan></text>
    <text
       xml:space="preserve"
       style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-size:20.0423069px;line-height:60.00000238%;font-family:'Domestic Manners';-inkscape-font-specification:'Domestic Manners';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       x="481.65875"
       y="1005.6507"
       id="text3657"
       sodipodi:linespacing="60.000002%"
       transform="matrix(0.99125487,0.20240736,-0.24685846,0.9584155,0,0)"
       inkscape:transform-center-x="-3.2066473"
       inkscape:transform-center-y="0.36333063"><tspan
         sodipodi:role="line"
         id="tspan3659"
         x="481.65875"
         y="1005.6507"
         style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;line-height:60.00000238%;font-family:RW;-inkscape-font-specification:'RW Medium';text-align:center;text-anchor:middle">Dry</tspan><tspan
         sodipodi:role="line"
         x="481.65875"
         y="1017.6761"
         id="tspan3665"
         style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;line-height:60.00000238%;font-family:RW;-inkscape-font-specification:'RW Medium';text-align:center;text-anchor:middle">hop'd</tspan><tspan
         sodipodi:role="line"
         x="481.65875"
         y="1031.4626"
         id="tspan3661"
         style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;line-height:60.00000238%;font-family:RW;-inkscape-font-specification:'RW Medium';text-align:center;text-anchor:middle">Hops</tspan><tspan
         sodipodi:role="line"
         x="481.65875"
         y="1043.488"
         id="tspan3663"
         style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;line-height:60.00000238%;font-family:RW;-inkscape-font-specification:'RW Medium';text-align:center;text-anchor:middle" /></text>
    <text
       xml:space="preserve"
       style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;font-size:25px;line-height:125%;font-family:RW;-inkscape-font-specification:'RW, Medium';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       id="text4691"
       sodipodi:linespacing="125%"
       x="-2.1428571"
       y="-15"><textPath
         xlink:href="#path3887"
         id="textPath4695"
         style="font-size:18.75px"><tspan
   id="tspan4693"
   dx="80.812202"
   style="font-size:18.75px">I can drink it</tspan></textPath></text>
    <g
       id="g3426"
       transform="matrix(-1,0,0,-1,641.15691,1940.2576)"
       style="stroke:none">
      <ellipse
         ry="38.88921"
         rx="34.891293"
         cy="1007.3622"
         cx="373.91425"
         id="path3887-6"
         style="opacity:1;fill:none;fill-opacity:1;fill-rule:nonzero;stroke:none;stroke-width:0.7179088;stroke-miterlimit:4;stroke-dasharray:none;stroke-dashoffset:0;stroke-opacity:1" />
      <text
         sodipodi:linespacing="125%"
         id="text3419"
         style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-size:18.75px;line-height:125%;font-family:'Domestic Manners';-inkscape-font-specification:'Domestic Manners';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
         xml:space="preserve"><textPath
           id="textPath3423"
           xlink:href="#path3887-6"><tspan
   dx="71.785721 0 0 -3.5714285"
   id="tspan3421"
   style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;font-family:RW;-inkscape-font-specification:'RW Medium';stroke:none">all by myself</tspan></textPath></text>
    </g>
    <text
       xml:space="preserve"
       style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-size:20.88526535px;line-height:80.00000119%;font-family:'Domestic Manners';-inkscape-font-specification:'Domestic Manners';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;display:inline;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       x="143.41379"
       y="1363.86"
       id="text3689-3"
       sodipodi:linespacing="80.000001%"
       transform="scale(1.1102167,0.90072505)"><tspan
         sodipodi:role="line"
         id="tspan3691-6"
         x="143.41379"
         y="1363.86"
         style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;font-size:25px;line-height:80.00000119%;font-family:RW;-inkscape-font-specification:'RW Medium';text-align:center;text-anchor:middle">The strongest juice</tspan><tspan
         sodipodi:role="line"
         x="143.41379"
         y="1383.86"
         style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;font-size:25px;line-height:80.00000119%;font-family:RW;-inkscape-font-specification:'RW Medium';text-align:center;text-anchor:middle"
         id="tspan3484">for everyday use</tspan></text>
  </g>
</svg>
XML
        return $xml;
    };
    $comic = Comic->new('whatever');
    $Comic::options{TRANSFORM} = 1;
    $comic->_findFrames();
}


sub makeNode {
    my ($xml) = @_;
    my $dom = XML::LibXML->load_xml(string => $xml);
    return $dom->documentElement();
}


sub failsOnBadAttribute : Test {
    eval {
        Comic::_transformed(
            makeNode('<text x="1" y="1" transform="matrix(1,2,3,4,5,6)"/>'), "foo");
    };
    like($@, qr/unsupported attribute/i);
}


sub noTransformation : Test {
    is(Comic::_transformed(
        makeNode('<text x="329.6062" y="-1456.9886"/>'), "x"), 
    329.6062);
}


sub matrix : Test {
    is(Comic::_transformed(makeNode(
        '<text x="5" y="7" transform="matrix(1,2,3,4,5,6)"/>'), "x"),
    1 * 5 + 3 * 7);
}


sub scale : Test {
    is(Comic::_transformed(makeNode(
        '<text x="5" y="7" transform="scale(7,9)"/>'), "x"),
    5 * 7);
}
