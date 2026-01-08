<?php
/**
 * Header estilo wiki
 */

$current_user = wp_get_current_user();
$site_url = get_bloginfo('url');
$site_name = get_bloginfo('name');
$site_description = get_bloginfo('description');
$login_url = wp_login_url();
$logout_url = wp_logout_url();
?>
<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
  <meta charset="<?php bloginfo('charset'); ?>">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><?php wp_title('|', true, 'right'); ?></title>
  <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>

<header class="wiki-header">
    <a href="<?php echo esc_url($site_url); ?>" class="wiki-logo">
      <?php echo esc_html($site_name); ?>
    </a>

    <nav class="wiki-nav">
      <?php
        wp_nav_menu([
          'theme_location' => 'main_nav',
          'menu_class'     => 'wiki-nav-list',
          'container'      => false
        ]);
      ?>
    </nav>

    <div class="wiki-user">
      <?php if (is_user_logged_in()): ?>
        <span class="wiki-user-name">
          <?php echo esc_html($current_user->display_name); ?>
        </span>
        <a href="<?php echo esc_url($logout_url); ?>" class="wiki-user-action">Cerrar sesión</a>
      <?php else: ?>
        <a href="<?php echo esc_url($login_url); ?>" class="wiki-user-action">Iniciar sesión</a>
      <?php endif; ?>
    </div>
</header>
