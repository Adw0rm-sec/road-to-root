<?php
require __DIR__ . '/inc/chrome.php';

// === PLANTED VULNERABILITY — Station A: unrestricted file upload ============
// The uploaded file is written straight into a web-served directory under the
// document root, with its original name and extension, and NO validation of
// type, extension, or content. Upload `shell.php`, then browse to
// /uploads/shell.php and it runs as www-data. (See share.php for the "fixed
// with a blacklist" version — which is also bypassable.)
$UPLOAD_DIR = __DIR__ . '/uploads';
$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['file'])) {
    $name = basename($_FILES['file']['name']);           // no type/ext check at all
    $dest = $UPLOAD_DIR . '/' . $name;
    if (move_uploaded_file($_FILES['file']['tmp_name'], $dest)) {
        $url = '/uploads/' . rawurlencode($name);
        $msg = "Uploaded. Your file is at <a href=\"$url\">$url</a>";
    } else {
        $msg = 'Upload failed.';
    }
}
// === END PLANTED VULNERABILITY =============================================

hs_header('Upload');
?>
<div class="card">
  <h1>Upload a file</h1>
  <p>Files are stored in your share folder and served back at
  <code>/uploads/&lt;name&gt;</code>. Any file type is accepted.</p>
  <?php if ($msg): ?><p class="ok"><?php echo $msg; ?></p><?php endif; ?>
  <form method="post" enctype="multipart/form-data">
    <label for="file">Choose a file</label>
    <input type="file" name="file" id="file" required>
    <input type="submit" value="Upload">
  </form>
  <p class="muted">Tip for teammates: anything you upload is immediately
  reachable by URL. Handy for sharing a quick script.</p>
</div>
<?php hs_footer(); ?>
