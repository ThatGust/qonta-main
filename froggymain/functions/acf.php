<?php
    
    if( function_exists("acf_add_options_page") ):
        acf_add_options_page(array(
            'page_title' 	=> 'Theme Options',
            'menu_title'	=> 'Theme Options',
            'menu_slug' 	=> 'theme-options',
            'redirect'		=> false //no sub page
            //'capability'=>'edit_posts',
            //'icon_url'=> get_template_directory_uri().'/images/logo.png',
        ));

        acf_add_options_sub_page(array(
            'page_title'=>'External services',
            'menu_title'=>'External services',
            'parent_slug'=>'theme-options',
        ));
    endif;
    

   function getHtmlButtonfLink($o_link, $custom_class=""){
      $html = '';
      $o_link_title = false;
      $o_link_url = false;
      $o_link_target = false;
      if($o_link):
         $o_link_title = $o_link["title"];
         $o_link_url = $o_link["url"];
         $o_link_target = $o_link["target"];
   
         $attr_target ='';
         if($o_link_target):
            $attr_target ='target="'.$o_link_target.'"';
         endif;
   
         $attr_class ='';
         if($custom_class):
            $attr_class ='class="'.$custom_class.'"';
         endif;
   
         $attr_href ='javascript:void(0);';
         if($o_link_url):
            $attr_href ='href="'.$o_link_url.'"';
         endif;
   
         $html = '<a '.$attr_href.' '.$attr_class.' '.$attr_target.' >'.$o_link_title.'</a>';
      endif;
      return $html;
   }
   