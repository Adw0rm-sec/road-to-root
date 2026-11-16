<?php
// Classes the preferences feature works with. Both are autoloadable wherever
// prefs are unserialized — which is the whole problem (see prefs.php).

// The benign class the portal actually stores in the `prefs` cookie.
class Prefs {
    public $theme  = 'light';
    public $layout = 'grid';
    public function __construct($theme = 'light', $layout = 'grid') {
        $this->theme = $theme; $this->layout = $layout;
    }
}

// === PLANTED VULNERABILITY — Station F: the deserialization gadget ==========
// A helper the maintenance tooling uses to run a queued cleanup command. It has
// a dangerous magic method: __wakeup() shells out to $this->cmd. Nothing calls
// it directly on the prefs path — but because prefs.php unserialize()s an
// attacker-controlled cookie, an attacker can hand it a serialized
// MaintenanceTask whose __wakeup() fires the moment the object is rebuilt.
//   payload: base64( O:15:"MaintenanceTask":1:{s:3:"cmd";s:N:"<shell>";} )
class MaintenanceTask {
    public $cmd = '';
    public function __wakeup() {
        if ($this->cmd !== '') {
            system($this->cmd);          // <-- runs on unserialize(), as www-data
        }
    }
}
// === END PLANTED VULNERABILITY =============================================
