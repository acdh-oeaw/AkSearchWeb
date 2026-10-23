<?php

declare(strict_types=1);

[$script, $configPath, $host, $username, $database, $passwordFile] = $argv;

if (!is_file($configPath) || !is_readable($configPath)) {
    fwrite(STDERR, "VuFind config is missing or unreadable\n");
    exit(1);
}

/** Quote a value for a double-quoted PHP INI setting. */
$quoteIni = static function (string $value): string {
    return '"' . addcslashes($value, "\\\"$") . '"';
};

$settings = [
    'database_driver' => 'mysql',
    'database_host' => $host,
    'database_username' => $username,
    'database_password_file' => $passwordFile,
    'database_name' => $database,
];
$managedKeys = array_fill_keys(array_merge(array_keys($settings), ['database', 'database_password']), true);
$lines = file($configPath);
$result = [];
$inDatabaseSection = false;
$foundDatabaseSection = false;
$writtenSettings = [];

foreach ($lines as $line) {
    if (preg_match('/^\s*\[([^\]]+)\]/', $line, $sectionMatch)) {
        if ($inDatabaseSection) {
            foreach ($settings as $key => $value) {
                if (!isset($writtenSettings[$key])) {
                    $result[] = $key . ' = ' . $quoteIni($value) . "\n";
                }
            }
        }
        $inDatabaseSection = strcasecmp(trim($sectionMatch[1]), 'Database') === 0;
        if ($inDatabaseSection) {
            $foundDatabaseSection = true;
            $writtenSettings = [];
        }
        $result[] = $line;
        continue;
    }

    if ($inDatabaseSection && preg_match('/^\s*;?\s*([A-Za-z0-9_]+)\s*=/', $line, $settingMatch)) {
        $key = strtolower($settingMatch[1]);
        if (isset($managedKeys[$key])) {
            if (isset($settings[$key])) {
                $result[] = $key . ' = ' . $quoteIni($settings[$key]) . "\n";
                $writtenSettings[$key] = true;
            }
            continue;
        }
    }

    $result[] = $line;
}

if ($inDatabaseSection) {
    foreach ($settings as $key => $value) {
        if (!isset($writtenSettings[$key])) {
            $result[] = $key . ' = ' . $quoteIni($value) . "\n";
        }
    }
} elseif (!$foundDatabaseSection) {
    $result[] = "\n[Database]\n";
    foreach ($settings as $key => $value) {
        $result[] = $key . ' = ' . $quoteIni($value) . "\n";
    }
}

if (file_put_contents($configPath, implode('', $result), LOCK_EX) === false) {
    fwrite(STDERR, "Could not update VuFind database settings\n");
    exit(1);
}
