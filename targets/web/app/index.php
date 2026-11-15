<?php require __DIR__ . '/inc/chrome.php'; hs_header('Home'); ?>

<div class="card">
  <h1>Hollow Share</h1>
  <p>Welcome to the Hollow Industries internal file exchange and support desk.
  Share files with your team, run quick network checks, and manage your
  preferences — all in one place.</p>
  <p class="muted">Signed in as <strong>guest</strong> ·
  running on <code><?php echo php_uname('n'); ?></code> ·
  PHP <?php echo PHP_VERSION; ?></p>
</div>

<div class="grid">
  <div class="feat">
    <h3>📤 <a href="/upload.php">Upload a file</a></h3>
    <p class="muted">Drop a file into your personal share folder and get a link to send to colleagues.</p>
  </div>
  <div class="feat">
    <h3>🖼️ <a href="/share.php">Share an image</a></h3>
    <p class="muted">Post a screenshot or diagram to the shared gallery. Images only.</p>
  </div>
  <div class="feat">
    <h3>🛰️ <a href="/tools.php">Network tools</a></h3>
    <p class="muted">Ping a host from the Hollow Share server to check reachability.</p>
  </div>
  <div class="feat">
    <h3>📖 <a href="/view.php?page=pages/home.php">Help centre</a></h3>
    <p class="muted">Browse the help articles for the portal.</p>
  </div>
  <div class="feat">
    <h3>👋 <a href="/preview.php">Greeting preview</a></h3>
    <p class="muted">Preview the welcome banner teammates will see when you share with them.</p>
  </div>
  <div class="feat">
    <h3>⚙️ <a href="/prefs.php">Preferences</a></h3>
    <p class="muted">Theme and layout options, remembered in your browser.</p>
  </div>
</div>

<?php hs_footer(); ?>
