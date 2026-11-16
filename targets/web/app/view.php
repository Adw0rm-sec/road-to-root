<?php
require __DIR__ . '/inc/chrome.php';
hs_header('Help centre');

// === PLANTED VULNERABILITY — Station D: Local File Inclusion -> RCE =========
// The help viewer includes whatever path the `page` parameter names, with no
// base-directory restriction and no sanitisation. This gives:
//   * arbitrary local file read (?page=/etc/passwd),
//   * source disclosure via wrappers (?page=php://filter/convert.base64-encode/resource=prefs.php),
//   * RCE by including a file you can write PHP into — e.g. poison the Apache
//     access log with a User-Agent carrying a PHP system() tag, then include
//     ?page=/var/log/apache2/access.log , and
//   * RCE via data:// / php://input wrappers, because php.ini ships with
//     allow_url_include=On (config/99-hollow.ini) — another planted mistake.
$page = $_GET['page'] ?? 'pages/home.php';
?>
<div class="card">
  <h2>Help articles</h2>
  <p class="muted">
    <a href="/view.php?page=pages/home.php">Overview</a> ·
    <a href="/view.php?page=pages/uploading.php">Uploading files</a> ·
    <a href="/view.php?page=pages/sharing.php">Sharing &amp; links</a> ·
    <a href="/view.php?page=pages/contact.php">Contact support</a>
  </p>
  <hr>
  <?php
    include $page;      // <-- the bug: unrestricted include of user input
  ?>
</div>
<?php
// === END PLANTED VULNERABILITY =============================================
hs_footer();
?>
