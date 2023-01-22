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
    my ($svg, @expected) = @_;
    my $comic = MockComic::make_comic($MockComic::XML => $svg);
    is_deeply([$comic->texts_in_language('English')], \@expected);
}


sub simple_texts : Tests {
    assert_order(<<'SVG', 1, 2, 3);
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
    assert_order(<<'SVG', 'Intro', 'Speak1', 'Meta1', 'Rotate1', 'Meta2', 'Speak2', 'Meta3', 'Speak3', 'Meta4', 'Rotate4');
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


sub text_on_ellipse : Tests {
    assert_order(<<'SVG', 'Left', 'This text goes on the path.', 'Right');
<g inkscape:label="English" inkscape:groupmode="layer" id="layer1">
    <text xml:space="preserve" id="text1884">
        <textPath xlink:href="#path932" id="textPath1014">
            <tspan id="tspan1882" style="stroke-width:0.264583px">This text goes on the path.</tspan>
        </textPath>
    </text>
    <text xml:space="preserve" x="14.095977" y="40.531601" id="text1773">
        <tspan sodipodi:role="line" id="tspan1771" style="stroke-width:0.264583px" x="14.095977" y="40.531601">Left</tspan>
    </text>
    <text xml:space="preserve" x="78.532928" y="39.46553" id="text4889">
        <tspan sodipodi:role="line" id="tspan4887" style="stroke-width:0.264583px" x="78.532928" y="39.46553">Right</tspan>
    </text>
    <ellipse id="path932" cx="52.033432" cy="41.421562" rx="21.347855" ry="8.6660538"/>
</g>
SVG
}


sub text_on_circle : Tests {
    assert_order(<<'SVG', 'Left', 'This text goes on the circle.', 'Right');
<g inkscape:label="English" inkscape:groupmode="layer" id="layer1">
    <text xml:space="preserve" id="text1884">
        <textPath xlink:href="#path954" id="textPath1036">
            <tspan id="tspan1882" style="stroke-width:0.264583px">This text goes on the circle.</tspan>
        </textPath>
    </text>
    <circle id="path954" cx="22.073423" cy="59.786758" r="17.729889"/>
    <text xml:space="preserve" x="-4.7570496" y="47.758087" id="text2719">
        <tspan sodipodi:role="line" id="tspan2717" style="stroke-width:0.264583px" x="-4.7570496" y="47.758087">Left</tspan>
    </text>
    <text xml:space="preserve" x="30.296965" y="51.988861" id="text6409">
        <tspan sodipodi:role="line" id="tspan6407" style="stroke-width:0.264583px" x="30.296965" y="51.988861">Right</tspan>
    </text>
</g>
SVG
}


sub text_on_path : Tests {
    assert_order(<<'SVG', 'Left', 'This text goes on the path.', 'Right');
<g inkscape:label="English" inkscape:groupmode="layer" id="layer1">
    <path id="path857"
       d="m 6.7076959,24.912254 c 1.9302852,2.754936 3.7949761,5.625938 4.7690721,8.878583 0.293965,0.981593 0.483483,1.991481 0.725224,2.987222 1.102456,6.26822 1.424747,12.639619 1.615627,18.990887 0.162389,1.182327 -0.257975,3.999722 0.429607,5.037584 0.71084,1.07297 1.395949,1.156372 2.542058,1.664589 3.925459,1.058942 8.054845,1.461614 12.10556,1.114047 1.618239,-0.307494 4.08496,-0.69796 5.019355,-2.292361 0.195413,-0.333441 0.287438,-0.717536 0.431157,-1.076303 0.590259,-3.550666 0.626102,-7.199861 0.447108,-10.78969 -0.289819,-3.180572 -0.893468,-6.319621 -1.274116,-9.488718 -0.119097,-1.71772 -0.457187,-3.519582 -0.0045,-5.218631 0.09897,-0.371454 0.265694,-0.721458 0.398539,-1.082188 2.060742,-3.086036 5.300353,-4.229851 8.749416,-5.077862 0.714682,-0.08131 1.424792,-0.236228 2.144043,-0.243922 3.751255,-0.04013 7.227239,1.80105 10.322221,3.722476 2.650686,1.728266 4.475314,4.248422 6.076807,6.917605 0.692087,1.274953 1.473658,2.508586 1.997935,3.865854 0.306406,1.349994 1.531639,1.551193 2.702973,1.904161 1.957226,0.535583 3.965318,0.856633 5.978594,1.089938 0.807066,0.09045 1.618099,0.129227 2.429774,0.133405 0.51376,-0.0013 1.027502,-0.0061 1.541256,-0.0085 0.588262,-0.0024 1.176528,-0.0024 1.764792,-0.0026 0.743387,0.05186 1.414008,-0.161182 2.061599,-0.50391 0.638773,-0.372181 1.165249,-0.89898 1.754704,-1.339609 0.262321,-0.229597 0.551656,-0.364628 0.886925,-0.440007 0.727684,-0.17467 0.480661,-1.203773 -0.247023,-1.0291 v 0 c -0.47077,0.11747 -0.901509,0.304403 -1.275085,0.622578 -0.545028,0.410289 -1.03841,0.889968 -1.617858,1.252474 -0.494512,0.266766 -0.990534,0.429614 -1.563587,0.37924 -0.589809,1.83e-4 -1.179621,1.22e-4 -1.769428,0.0026 -0.510338,0.0024 -1.020664,0.0071 -1.531006,0.0085 -0.772789,-0.0037 -1.544957,-0.04046 -2.313384,-0.126402 -1.951665,-0.2256 -3.898408,-0.535821 -5.796336,-1.052372 -0.332438,-0.09912 -1.383651,-0.359659 -1.693113,-0.536099 -0.208582,-0.118922 -0.236263,-0.571461 -0.327171,-0.737243 -0.550315,-1.411944 -1.349174,-2.70328 -2.077278,-4.027816 -1.6906,-2.812335 -3.629848,-5.456684 -6.426761,-7.272409 -3.316457,-2.050131 -6.990114,-3.937089 -11.001274,-3.874089 -0.764032,0.01201 -1.51778,0.178612 -2.276668,0.267919 -3.942144,0.982435 -7.202051,2.175516 -9.490967,5.747052 -0.149026,0.423127 -0.336304,0.834668 -0.447077,1.269381 -0.459121,1.801741 -0.140729,3.696726 -0.0019,5.515879 0.378376,3.144796 0.973495,6.260206 1.267894,9.415635 0.17553,3.449555 0.123542,6.946484 -0.38173,10.366623 -0.08684,0.259419 -0.138978,0.533173 -0.260522,0.778256 -0.662583,1.336024 -3.041764,1.64619 -4.290597,1.905932 -3.878504,0.346149 -7.83288,-0.06079 -11.599894,-1.033973 C 16.781853,61.328121 15.625142,60.985708 15.258589,60.494945 14.558138,59.55714 15.085858,56.812165 14.875406,55.737118 14.68212,49.312237 14.355157,42.866577 13.230142,36.527171 12.976409,35.492298 12.777373,34.442463 12.468943,33.422555 11.449321,30.050898 9.521292,27.065515 7.5046905,24.215937 7.0123293,23.652363 6.2153162,24.348667 6.7076774,24.912241 Z"/>
    <text xml:space="preserve" id="text1884">
        <textPath xlink:href="#path857" id="textPath2860">
            <tspan id="tspan1882" style="stroke-width:0.264583px">This text goes on the path.</tspan>
        </textPath>
    </text>
    <text xml:space="preserve" x="1.0821283" y="37.15921" id="text2907">
        <tspan sodipodi:role="line" id="tspan2905" style="stroke-width:0.264583px" x="1.0821283" y="37.15921">Left</tspan>
    </text>
    <text xml:space="preserve" x="62.078888" y="55.123356" id="text3857">
        <tspan sodipodi:role="line" id="tspan3855" style="stroke-width:0.264583px" x="62.078888" y="55.123356">Right</tspan>
    </text>
</g>
SVG
}


sub complains_about_text_on_something_else : Tests {
    my $svg = <<'SVG';
<g inkscape:label="English" inkscape:groupmode="layer" id="layer1">
    <whatever id="path857"/>
    <text xml:space="preserve" id="text1884">
        <textPath xlink:href="#path857" id="textPath2860">
            <tspan id="tspan1882" style="stroke-width:0.264583px">This text goes on the path.</tspan>
        </textPath>
    </text>
    <text xml:space="preserve" x="1.0821283" y="37.15921" id="text2907">
        <tspan sodipodi:role="line" id="tspan2905" x="1.0821283" y="37.15921">To trigger sorting</tspan>
    </text>
</g>
SVG
    my $comic = MockComic::make_comic($MockComic::XML => $svg);
    eval {
        $comic->texts_in_language('English');
    };
    like($@, qr{cannot handle}i, 'should say what is wrong');
    like($@, qr{whatever}, 'should say the element type it cannot handle');
    like($@, qr{text1884}, 'should say where the path was used');
}


sub complains_about_missing_textpath_reference : Tests {
    my $svg = <<'SVG';
<g inkscape:label="English" inkscape:groupmode="layer" id="layer1">
    <text xml:space="preserve" id="text1884">
        <textPath xlink:href="#doesNotExist" id="textPath2860">
            <tspan id="tspan1882" style="stroke-width:0.264583px">This text goes on the path.</tspan>
        </textPath>
    </text>
    <text xml:space="preserve" x="62.078888" y="55.123356" id="text3857">
        <tspan sodipodi:role="line" id="tspan3855" x="62.078888" y="55.123356">To trigger sorting</tspan>
    </text>
</g>
SVG
    my $comic = MockComic::make_comic($MockComic::XML => $svg);
    eval {
        $comic->texts_in_language('English');
    };
    like($@, qr{not found}i, 'should say what is wrong');
    like($@, qr{doesNotExist}, 'should give the missing id');
    like($@, qr{text1884}, 'should say where the path was used');
}


sub complains_about_duplicated_text_path_ids : Tests {
    my $svg = <<'SVG';
<g inkscape:label="English" inkscape:groupmode="layer" id="layer1">
    <path id="doubleMeId"
       d="m 6.7076959,24.912254 c 1.9302852,2.754936 3.7949761,5.625938 6.7076774,24.912241 Z"/>
    <path id="doubleMeId"
       d="m 6.7076959,24.912254 c 1.9302852,2.754936 3.7949761,5.625938 6.7076774,24.912241 Z"/>
    <text xml:space="preserve" id="text1884">
        <textPath xlink:href="#doubleMeId" id="textPath2860">
            <tspan id="tspan1882" style="stroke-width:0.264583px">This text goes on the path.</tspan>
        </textPath>
    </text>
    <text xml:space="preserve" x="62.078888" y="55.123356" id="text3857">
        <tspan sodipodi:role="line" id="tspan3855" x="62.078888" y="55.123356">To trigger sorting</tspan>
    </text>
</g>
SVG
    my $comic = MockComic::make_comic($MockComic::XML => $svg);
    eval {
        $comic->texts_in_language('English');
    };
    like($@, qr{duplicated}i, 'should say what is wrong');
    like($@, qr{doubleMeId}, 'should give the missing id');
    like($@, qr{text1884}, 'should say where the path was used');
}


sub complains_about_bad_path_draw : Tests {
    my $svg = <<'SVG';
<g inkscape:label="English" inkscape:groupmode="layer" id="layer1">
    <path id="thePath" d=""/>
    <text xml:space="preserve" id="text1884">
        <textPath xlink:href="#thePath" id="textPath2860">
            <tspan id="tspan1882" style="stroke-width:0.264583px">This text goes on the path.</tspan>
        </textPath>
    </text>
    <text xml:space="preserve" x="62.078888" y="55.123356" id="text3857">
        <tspan sodipodi:role="line" id="tspan3855" x="62.078888" y="55.123356">To trigger sorting</tspan>
    </text>
</g>
SVG
    my $comic = MockComic::make_comic($MockComic::XML => $svg);
    eval {
        $comic->texts_in_language('English');
    };
    like($@, qr{cannot parse}i, 'should say what is wrong');
    like($@, qr{thePath}, 'should give the id of the base path');
}


sub complains_about_empty_text_node_without_tspan_and_coordinates : Tests {
    my $svg = <<'SVG';
<g inkscape:label="MetaEnglish" inkscape:groupmode="layer" id="layer1">
    <text xml:space="preserve" id="text1884" style=""/>
    <text xml:space="preserve" id="text1234" style="">
        <tspan x="1" y="1">Needs more than one text so that sorting happens</tspan>
    </text>
</g>
SVG
    my $comic = MockComic::make_comic($MockComic::XML => $svg);
    $comic->texts_in_language('English');
    like($comic->{warnings}[0], qr{no coordinates}i, 'should say what is wrong');
    like($comic->{warnings}[0], qr{text1884}, 'should give the id of the base path');
}
