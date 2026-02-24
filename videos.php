<?php
// Suppress any PHP warnings/notices that might break JSON output
error_reporting(0);
ini_set('display_errors', '0');

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$videoExtensions = ['mp4', 'avi', 'mov', 'flv'];
$videos = [];

// Scan current directory
$files = @scandir(__DIR__);

if ($files === false) {
    echo json_encode(['error' => 'Failed to read directory']);
    exit;
}

foreach ($files as $file) {
    // Skip . and .. directories
    if ($file === '.' || $file === '..') {
        continue;
    }
    
    // Check if file has a video extension
    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
    if (in_array($ext, $videoExtensions)) {
        $videos[] = $file;
    }
}

// Sort alphabetically
sort($videos);

echo json_encode($videos);
?>
