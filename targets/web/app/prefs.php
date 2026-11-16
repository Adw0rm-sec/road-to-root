<?php
require __DIR__ . '/inc/chrome.php';
require __DIR__ . '/inc/prefs_lib.php';

// === PLANTED VULNERABILITY — Station F: insecure deserialization ============
// Preferences are "remembered" by storing a base64(serialize($prefs)) blob in
// the `prefs` cookie and unserialize()ing it on every page load. The cookie is
// fully attacker-controlled, and unserialize() will instantiate ANY class in
// scope and fire its magic methods (__wakeup / __destruct). inc/prefs_lib.php
// ships a MaintenanceTask gadget whose __wakeup() runs system($this->cmd) — so
// a crafted cookie is RCE. The fix is json_encode/json_decode, or a strict
// `allowed_classes` list on unserialize().
$prefs = new Prefs();
if (!empty($_COOKIE['prefs'])) {
    $blob = base64_decode($_COOKIE['prefs'], true);
    if ($blob !== false) {
        $obj = unserialize($blob);          // <-- the bug: no allowed_classes
        if ($obj instanceof Prefs) {
            $prefs = $obj;
        }
    }
}

// Saving prefs just re-issues the cookie as a serialized Prefs object.
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $prefs = new Prefs($_POST['theme'] ?? 'light', $_POST['layout'] ?? 'grid');
    setcookie('prefs', base64_encode(serialize($prefs)), 0, '/');
}
// === END PLANTED VULNERABILITY =============================================

hs_header('Preferences');
?>
<div class="card">
  <h1>Preferences</h1>
  <p>Your display preferences are remembered in a <code>prefs</code> cookie so
  the portal looks the same each visit.</p>
  <form method="post">
    <label for="theme">Theme</label>
    <select name="theme" id="theme">
      <option <?php if($prefs->theme==='light')echo 'selected';?>>light</option>
      <option <?php if($prefs->theme==='dark') echo 'selected';?>>dark</option>
    </select>
    <label for="layout">Layout</label>
    <select name="layout" id="layout">
      <option <?php if($prefs->layout==='grid')echo 'selected';?>>grid</option>
      <option <?php if($prefs->layout==='list')echo 'selected';?>>list</option>
    </select>
    <input type="submit" value="Save preferences">
  </form>
  <p class="muted">Current: theme=<code><?php echo htmlspecialchars($prefs->theme); ?></code>,
  layout=<code><?php echo htmlspecialchars($prefs->layout); ?></code></p>
</div>
<?php hs_footer(); ?>
