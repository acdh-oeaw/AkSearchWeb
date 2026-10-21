<?php

declare(strict_types=1);

$manifestPath = $argv[1] ?? '';
if ($manifestPath === '' || !is_file($manifestPath) || !is_readable($manifestPath)) {
    fwrite(STDERR, "Usage: php update-vufind-dependencies.php /path/to/vufind/composer.json\n");
    exit(2);
}

try {
    $manifest = json_decode(file_get_contents($manifestPath), true, 512, JSON_THROW_ON_ERROR);
} catch (JsonException $exception) {
    fwrite(STDERR, "Could not parse VuFind Composer manifest: {$exception->getMessage()}\n");
    exit(1);
}

if (($manifest['name'] ?? null) !== 'vufind/vufind') {
    fwrite(STDERR, "Unexpected Composer package in {$manifestPath}\n");
    exit(1);
}

$updates = [
    'require' => [
        'guzzlehttp/guzzle' => ['7.9.2', '7.16.0'],
        'league/commonmark' => ['2.5.3', '2.10.4'],
        'pear/http_request2' => ['2.6.0', '2.8.0'],
        'symfony/yaml' => ['6.4.12', '6.4.48'],
    ],
    'require-dev' => [
        'firebase/php-jwt' => ['6.10.1', '7.2.1'],
        'phpunit/phpunit' => ['10.5.36', '10.5.66'],
        'squizlabs/php_codesniffer' => ['3.10.3', '3.13.6'],
    ],
];

foreach ($updates as $section => $packages) {
    foreach ($packages as $package => [$expectedVersion, $targetVersion]) {
        $currentVersion = $manifest[$section][$package] ?? null;
        if (!in_array($currentVersion, [$expectedVersion, $targetVersion], true)) {
            fwrite(STDERR, sprintf(
                "Unexpected %s version for %s: expected %s or %s, found %s\n",
                $section,
                $package,
                $expectedVersion,
                $targetVersion,
                is_string($currentVersion) ? $currentVersion : 'missing'
            ));
            exit(1);
        }
        $manifest[$section][$package] = $targetVersion;
    }
}

// Prevent Composer from installing bundled Solr or Swagger UI as a side effect
// of dependency updates in the container build. Swagger UI is installed explicitly.
foreach (['phing-install-dependencies', 'post-install-cmd', 'post-update-cmd'] as $script) {
    unset($manifest['scripts'][$script]);
}

try {
    $updatedManifest = json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR) . "\n";
} catch (JsonException $exception) {
    fwrite(STDERR, "Could not encode updated VuFind Composer manifest: {$exception->getMessage()}\n");
    exit(1);
}

if (file_put_contents($manifestPath, $updatedManifest) === false) {
    fwrite(STDERR, "Could not write updated VuFind Composer manifest: {$manifestPath}\n");
    exit(1);
}
