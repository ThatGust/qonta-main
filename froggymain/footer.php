<?php
/**
 * Footer principal del tema wiki
 */
?>
<footer class="site-footer">
    <div class="footer-content">
        <p>&copy; <?php echo date('Y'); ?> <?php bloginfo('name'); ?>. Todos los derechos reservados.</p>
        <p>
            <a href="<?php echo esc_url(home_url('/')); ?>">Inicio</a> |
            <a href="<?php echo esc_url(home_url('/acerca-de')); ?>">Acerca de</a> |
            <a href="<?php echo esc_url(home_url('/contacto')); ?>">Contacto</a>
        </p>
    </div>
</footer>

<?php wp_footer(); ?>
</body>
</html>
