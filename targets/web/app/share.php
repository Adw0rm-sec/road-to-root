<?php
require __DIR__ . '/inc/chrome.php';

// === PLANTED VULNERABILITY — Station B: upload filter bypass ================
// This is the "hardened" uploader: the admin tried to stop webshells with a
// deny-list of extensions and an image Content-Type check. Both are weak:
//   * the deny-list misses .pht / .php5 / .phar-as-not-last and double
//     extensions, and Apache is configured (config/hollow-share.conf) to run
//     .pht / .php5 / .phtml AND any file with .php anywhere in the name;
//   * the Content-Type is attacker-controlled (spoof image/gif);
//   * /var/www/html/shares allows .htaccess overrides, so an uploaded
//     .htaccess `AddType application/x-httpd-php .jpg` makes .jpg run as PHP.
// Intended win: GIF89a magic bytes + a non-blocked PHP extension + a spoofed
// image Content-Type.
$SHARE_DIR  = __DIR__ . '/shares';
$BLOCK_EXT  = ['php', 'phtml', 'php4', 'php3', 'phps'];   // naive deny-list (misses pht, php5, double-ext)
$OK_CTYPE   = ['image/jpeg', 'image/png', 'image/gif'];
$msg = ''; $err = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['image'])) {
    $name  = basename($_FILES['image']['name']);
    $ext   = strtolower(pathinfo($name, PATHINFO_EXTENSION));  // only the LAST extension
    $ctype = $_FILES['image']['type'];                          // client-supplied, trusted
    if (in_array($ext, $BLOCK_EXT, true)) {
        $err = "Blocked: .$ext files are not allowed.";
    } elseif (!in_array($ctype, $OK_CTYPE, true)) {
        $err = "Blocked: images only (got Content-Type: " . htmlspecialchars($ctype) . ").";
    } else {
        $dest = $SHARE_DIR . '/' . $name;
        if (move_uploaded_file($_FILES['image']['tmp_name'], $dest)) {
            $url = '/shares/' . rawurlencode($name);
            $msg = "Shared. View it at <a href=\"$url\">$url</a>";
        } else {
            $err = 'Upload failed.';
        }
    }
}
// === END PLANTED VULNERABILITY =============================================

hs_header('Share an image');
?>
<div class="card">
  <h1>Share an image</h1>
  <p>Post a screenshot or diagram to the shared gallery. We only accept image
  files &mdash; <code>.php</code> and friends are blocked, and the file must be
  sent with an image <code>Content-Type</code>.</p>
  <?php if ($msg): ?><p class="ok"><?php echo $msg; ?></p><?php endif; ?>
  <?php if ($err): ?><p class="warn"><?php echo $err; ?></p><?php endif; ?>
  <form method="post" enctype="multipart/form-data">
    <label for="image">Choose an image</label>
    <input type="file" name="image" id="image" accept="image/*" required>
    <input type="submit" value="Share">
  </form>
  <p class="muted">Blocked extensions: <code>.php .phtml .php4 .php3 .phps</code>.
  Shared files live under <code>/shares/</code>.</p>
</div>
<?php hs_footer(); ?>
