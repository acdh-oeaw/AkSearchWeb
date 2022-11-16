#!/usr/local/bin/php
<?php
/*
 * The MIT License
 *
 * Copyright 2022 Austrian Centre for Digital Humanities and Cultural Heritage.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

/*
 * Harvests DeGruyter MARC XML records over FTP and splits them into smaller
 * files procesable by the batch-import-marc.sh (basically in the same format
 * as produced by the {vufind}/harvest/harvest_oai.php).
 */
if (count($argv) < 3) {
    echo "Usage: $argv[0] cfgFile password\n";
    exit(1);
}
$cfg = json_decode(file_get_contents($argv[1]));
$missingCfg = array_diff(["server", "login", "ftpPattern", "datePattern", "targetDir", "recordsPerFile", "xmlRecord", "xmlCollection"], array_keys((array) $cfg));
if (count($missingCfg) > 0) {
    die("Config files missed configuration properties: " . implode(', ', $missingCfg) . "\n");
}
$lastUpdateFile = "$cfg->targetDir/lastDate";
if (file_exists($lastUpdateFile)) {
    $lastUpdate = trim(file_get_contents($lastUpdateFile));
} else {
    $lastUpdate = null;
}
$cfg->pswd = $argv[2];

function execFtp($cfg, $command) {
    $cmd = "$cfg->ftpInit;open $cfg->server;user $cfg->login $cfg->pswd;$command;quit;";
    $cmd = "/usr/bin/lftp -e " . escapeshellarg($cmd);
    exec($cmd, $output, $result);
    if ($result !== 0) {
        echo "ERROR:\n$cmd\n$result\n".implode("\n", $output);
        return false;
    }
    return count($output) === 0 ? ['OK'] : $output;
}

// list and filter files
$files = execFtp($cfg, "ls -1") ?: die('Failed listing files');
$files = array_filter($files, fn($i) => preg_match($cfg->ftpPattern, $i));
if (count($files) === 0) {
    die("No matching files found on the FTP server (the pattern is defined in $argv[1])");
}
sort($files);
if ($lastUpdate === null) {
    $files = [array_pop($files)];
} else {
    $files = array_filter($files, fn($i) => preg_replace($cfg->ftpPattern, '$1', $i) > $lastUpdate);
}
if (count($files) === 0) {
    die("No new data (last processed date $lastUpdate)\n");
}

// process files
$tmpDir = "$cfg->targetDir/tmp";
if (!is_dir($tmpDir)) {
    mkdir($tmpDir, 0770, true);
}
$tmpFile = "$tmpDir/tmpDwnld";
foreach ($files as $file) {
    // download and extract MARC-XML
    echo "Downloading $file\n";
    execFtp($cfg, "get " . escapeshellarg($file) . " -o " . escapeshellarg($tmpFile)) ?: die("Failed to download $file\n");
    $zip = new ZipArchive();
    $res = $zip->open($tmpFile);
    if ($res !== true) {
        die("Failed to open zip archive $file\n");
    }
    $zipfiles = [];
    for ($i = 0; $i < $zip->numFiles; $i++) {
        $zipfile = $zip->getNameIndex($i);
        $update = strpos($zipfile, '_UPDATE_') !== false;
        if ($lastUpdate === null && !$update || $lastUpdate !== null && $update) {
            $zipfiles[] = $zipfile;
        }
    }
    $origfile = $zipfiles[0];
    if (count($zipfiles) !== 1) {
        die("Can not find correct file in the zip archive\n");
    }
    echo "Extracting $origfile\n";
    $zip->extractTo($tmpDir, $origfile);
    $zip->close();
    unlink($tmpFile);
    rename("$tmpDir/$origfile", $tmpFile);
    $date = preg_replace($cfg->datePattern, '$1', $origfile);

    // split into chunks
    $xmlCollectionEnd = preg_replace('`^<([[:alnum:]]+)[ >].*$`', '</$1>', $cfg->xmlCollection);
    $chunkNamePrefix = $cfg->targetDir . '/' . substr($origfile, 0, -4);
    $chunk = 0;
    $recordCount = $cfg->recordsPerFile;
    $ofh = null;
    $ifh = fopen($tmpFile, 'r');
    $tmpstr = fread($ifh, 100000);
    $tmpstr = preg_replace("`^.*(<" . $cfg->xmlRecord . "[ >])`s", '$1', $tmpstr, ); // skip everything up to first record entry
    while (!feof($ifh)) {
        $tmpstr .= fread($ifh, 1000000); // read 1 MB
        $records = preg_split("`</$cfg->xmlRecord>`", $tmpstr);
        $tmpstr = array_pop($records); // the last one is incomplete (or empty)
        foreach ($records as $record) {
            if ($recordCount >= $cfg->recordsPerFile) {
                if ($ofh) {
                    fwrite($ofh, "$xmlCollectionEnd\n");
                    fclose($ofh);
                }
                $chunk++;
                $ofName = sprintf("%s_part%04d.xml", $chunkNamePrefix, $chunk);
                echo "Creating $ofName\n";
                $ofh = fopen($ofName, "w");
                fwrite($ofh, $cfg->xmlCollection . "\n");
                $recordCount = 0;
            }
            fwrite($ofh, "$record</$cfg->xmlRecord>\n");
            $recordCount++;
        }
    }
    fclose($ifh);
    fwrite($ofh, "$xmlCollectionEnd\n");
    fclose($ofh);
    file_put_contents($lastUpdateFile, $date);
}

