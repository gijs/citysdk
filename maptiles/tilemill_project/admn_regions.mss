#-admr_regions[admn_level>=3][admn_level<=4] {
  line-color:@waag;
  line-cap:butt;
  line-join:miter;
  line-opacity:  0.5;
  
  
  text-name: '[cdk_id]';
  text-face-name: @sans_italic;
  text-fill: @waag;
 /* text-halo-fill: fadeout(lighten(white,5%),25%);*/
  text-halo-radius: 1;
  /*text-placement: line;
  text-min-distance: 400;*/
  text-size: 10;
  
  [admn_level=3] {
  	line-width:2.4;
  }
  [admn_level=4] {
  	line-width:1.2;
  }

}