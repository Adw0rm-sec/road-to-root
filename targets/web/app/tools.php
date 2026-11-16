<?php
require __DIR__ . '/inc/chrome.php';

// === PLANTED VULNERABILITY — Station C: OS command injection ================
// The "ping" feature builds a shell command by string-concatenating the
// user-supplied host straight into system(). Any shell metacharacter in `host`
// (`;`, `|`, `$(...)`, `&&`) runs as www-data. No allow-list, no escaping,
// no escapeshellarg().
$out = ''; $cmd = '';
if (isset($_GET['host']) && $_GET['host'] !== '') {
    $host = $_GET['host'];
    $cmd  = "ping -c 1 -W 1 " . $host;      // <-- raw concatenation, the bug
    $out  = shell_exec($cmd . ' 2>&1');
}
// === END PLANTED VULNERABILITY =============================================

hs_header('Network Tools');
?>
<div class="card">
  <h1>Network tools</h1>
  <p>Check whether a host is reachable from the Hollow Share server.</p>
  <form method="get">
    <label for="host">Host or IP</label>
    <input type="text" name="host" id="host" placeholder="10.0.0.1"
           value="<?php echo htmlspecialchars($_GET['host'] ?? ''); ?>">
    <input type="submit" value="Ping">
  </form>
  <?php if ($cmd): ?>
  <p class="muted">Running: <code><?php echo htmlspecialchars($cmd); ?></code></p>
  <pre><?php echo htmlspecialchars($out); ?></pre>
  <?php endif; ?>
</div>
<?php hs_footer(); ?>
