<?php
$fn = "recorded_data.json";
$file = fopen($fn, "a+");
$size = filesize($fn);
$space.= "\n";
if($_POST['json']) fwrite($file, $_POST['json']);

$text = fread($file, $size);
fwrite ($file, $space);
fclose($file);
?>
