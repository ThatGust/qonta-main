<?php
/**
 * Template Name: Página de Inicio Wiki
 */

get_header();

$current_user = wp_get_current_user();

$greeting_image = get_field('greeting_image');
$greeting_title = get_field('greeting_title');
$greeting_text  = get_field('greeting_text');
?>

<main class="wiki-main-content">
  <div class="wiki-container">

    <!-- SALUDO / GREETING -->
    <section class="wiki-greeting-block">
      <div class="wiki-greeting-box">
        <?php if ($greeting_image): ?>
          <div class="wiki-greeting-img">
            <img src="<?php echo esc_url($greeting_image['url']); ?>" alt="Greeting Image">
          </div>
        <?php endif; ?>

        <div class="wiki-greeting-content">
          <?php if ($greeting_title): ?>
            <h2><?php echo esc_html($greeting_title); ?></h2>
          <?php endif; ?>
          <?php if ($greeting_text): ?>
            <p><?php echo esc_html($greeting_text); ?></p>
          <?php endif; ?>
        </div>
      </div>
    </section>

    <section class="wiki-topics-block">
      <h3 class="section-title">Tópicos Generales</h3>
      <div class="wiki-topics-grid">
        <?php
          $topics = new WP_Query([
            'post_type'      => 'topic', 
            'posts_per_page' => -1,
            'orderby'        => 'menu_order',
            'order'          => 'ASC'
          ]);

          if ($topics->have_posts()):
            while ($topics->have_posts()): $topics->the_post();

              $topic_icon = get_field('topic_icon');
              $topic_summary = get_field('topic_summary'); 
        ?>
          <div class="wiki-topic-card">
            <?php if ($topic_icon): ?>
              <div class="wiki-topic-icon">
                <img src="<?php echo esc_url($topic_icon['url']); ?>" alt="Ícono de <?php the_title(); ?>">
              </div>
            <?php endif; ?>
            <div class="wiki-topic-info">
              <h4><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h4>
              <?php if ($topic_summary): ?>
                <p><?php echo esc_html($topic_summary); ?></p>
              <?php endif; ?>
            </div>
          </div>
        <?php
            endwhile;
            wp_reset_postdata();
          else:
            echo '<p>No se han encontrado tópicos aún.</p>';
          endif;
        ?>
      </div>
    </section>

  </div>
</main>

<?php get_footer(); ?>
