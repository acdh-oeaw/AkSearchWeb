#!/usr/local/bin/php
<?php
// Fallback script adding local dependencies to AkSearch's composer.json
// Can be dismissed when AkSearch will become a composer package

if (!file_exists($argv[1] ?? '')) {
    exit("Can't find input file\n");
}

$target = '/var/www/vufind/composer.json';
if (!file_exists($target)) {
    exit("$target doesn't exist\n");
}

$src = json_decode(file_get_contents($argv[1]));
$dst = json_decode(file_get_contents($target));
foreach ($src->require as $lib => $version) {
    $dst->require->$lib = $version;
}
file_put_contents($target, json_encode($dst));

