<?php
require __DIR__ . '/inc/chrome.php';
require __DIR__ . '/vendor/autoload.php';   // Twig, installed via composer at build

use Twig\Environment;
use Twig\Loader\ArrayLoader;

// === PLANTED VULNERABILITY — Station E: Server-Side Template Injection ======
// The greeting preview renders the user-supplied `name` by splicing it INTO a
// template string and compiling that whole string as a Twig template. Because
// the attacker controls template syntax (not just data), {{7*7}} evaluates and
// Twig sandbox-escape gadgets reach PHP functions:
//   {{ ['id']|map('system')|join }}
//   {{ ['cat /var/www/flag.txt']|filter('system') }}
// The safe pattern is to pass `name` as a RENDER VARIABLE into a fixed
// template, never to build the template text from user input.
$rendered = null; $name = $_GET['name'] ?? '';
if ($name !== '') {
    $twig = new Environment(new ArrayLoader());
    $tplSource = "<p>Hi {$name}, a file has been shared with you on Hollow Share.</p>";
    $rendered = $twig->createTemplate($tplSource)->render();   // <-- user input compiled as template
}
// === END PLANTED VULNERABILITY =============================================

hs_header('Greeting preview');
?>
<div class="card">
  <h1>Greeting preview</h1>
  <p>Preview the welcome banner teammates see when you share a file with them.
  Type a name and we'll render the greeting.</p>
  <form method="get">
    <label for="name">Recipient name</label>
    <input type="text" name="name" id="name" placeholder="Alex"
           value="<?php echo htmlspecialchars($name); ?>">
    <input type="submit" value="Preview">
  </form>
  <?php if ($rendered !== null): ?>
  <h2>Preview</h2>
  <div class="card" style="background:#f7fafc;"><?php echo $rendered; ?></div>
  <?php endif; ?>
</div>
<?php hs_footer(); ?>
