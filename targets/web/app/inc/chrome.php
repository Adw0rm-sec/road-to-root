<?php
// Shared HTML chrome for the "Hollow Share" support portal.
// In-world: a small file-sharing / support desk web app. Out-of-world: the
// surface for Chapter 09's six web-RCE stations. Nothing security-relevant
// lives here — the planted bugs are each in their own endpoint.

function hs_header(string $title = 'Hollow Share'): void {
    echo "<!doctype html>\n";
    ?>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?php echo htmlspecialchars($title); ?> · Hollow Share</title>
<link rel="stylesheet" href="/style.css">
</head>
<body>
<header class="topbar">
  <div class="brand"><a href="/index.php">📦 Hollow&nbsp;Share</a></div>
  <nav>
    <a href="/index.php">Home</a>
    <a href="/upload.php">Upload</a>
    <a href="/share.php">Share</a>
    <a href="/tools.php">Network&nbsp;Tools</a>
    <a href="/view.php?page=pages/home.php">Help</a>
    <a href="/preview.php">Preview</a>
    <a href="/prefs.php">Preferences</a>
  </nav>
</header>
<main>
    <?php
}

function hs_footer(): void {
    ?>
</main>
<footer class="foot">
  <span>Hollow&nbsp;Industries · Internal File Exchange &amp; Support Desk</span>
  <span class="muted">Hollow Share v2.3 — &copy; 2026. For internal use only.</span>
</footer>
</body>
</html>
    <?php
}
