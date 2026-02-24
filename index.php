<?php
// Get video files
$videoExtensions = ['mp4', 'avi', 'mov', 'mkv', 'flv'];
$files = scandir(__DIR__);
$videoFiles = [];

foreach ($files as $file) {
    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
    if (in_array($ext, $videoExtensions)) {
        $videoFiles[] = $file;
    }
}
sort($videoFiles);

// Handle AJAX request for video list
if (isset($_GET['action']) && $_GET['action'] === 'get_videos') {
    header('Content-Type: application/json');
    echo json_encode($videoFiles);
    exit;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>QR Sync Video</title>
    <script src="https://unpkg.com/peerjs@1.5.2/dist/peerjs.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
    <script src="https://unpkg.com/html5-qrcode"></script> 
    
    <style>
        body { font-family: 'Segoe UI', sans-serif; text-align: center; background: #1a1a1a; color: #eee; margin: 0; padding: 20px; min-height: 100vh; display: flex; flex-direction: column; }
        .container { max-width: 600px; margin: auto; }
        #qrcode { background: white; padding: 10px; display: inline-block; margin: 20px; border-radius: 8px; cursor: pointer; }
        #reader { width: 100%; max-width: 400px; margin: auto; border: 1px solid #555; }
        video { width: 100%; border-radius: 12px; margin-top: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
        .btn { padding: 12px 24px; font-size: 16px; border: none; border-radius: 25px; cursor: pointer; margin: 5px; transition: 0.3s; }
        .qr-toggle-link { color: #00c853; cursor: pointer; text-decoration: underline; font-size: 16px; }
        .btn-host { background: #00c853; color: white; }
        .btn-join { background: #2979ff; color: white; }
        .hidden { display: none; }
        .video-selector { padding: 10px; font-size: 16px; border-radius: 8px; background: #2a2a2a; color: #eee; border: 1px solid #555; margin: 10px 0; width: 100%; max-width: 400px; cursor: pointer; }
        .footer { margin-top: auto; padding-top: 20px; font-size: 14px; color: #bbb; display: flex; align-items: center; justify-content: center; gap: 12px; flex-wrap: wrap; }
        .footer a { color: #bbb; text-decoration: none; }
        .footer a:hover { text-decoration: underline; }
        .kofi-link { display: inline-flex; align-items: center; gap: 6px; }
        .kofi-logo { height: 16px; width: auto; vertical-align: middle; }
    </style>
</head>
<body>

<div class="container">
    <h2>P2P Video Sync 0.4.0</h2>
    
    <div id="setup-ui">
        <button class="btn btn-host" onclick="startAsHost()">Be the Host (Show QR)</button>
        <button class="btn btn-join" onclick="startAsClient()">Join Session (Scan QR)</button>
    </div>

    <div id="host-ui" class="hidden">
        <a class="qr-toggle-link hidden" onclick="toggleQR()">Show QR</a>
        <div id="qrcode-container">
            <p>Scan this with the other tablet (click to close):</p>
            <div id="qrcode" onclick="hideQR()"></div>
            <p>ID: <span id="my-id">...</span></p>
        </div>
    </div>

    <div id="client-ui" class="hidden">
        <div id="reader"></div>
        <p>Pointing your camera at the Host QR code...</p>
    </div>

    <div style="margin: 20px 0;">
        <label for="video-select" style="display: block; margin-bottom: 5px;">Select Video:</label>
        <select id="video-select" class="video-selector" onchange="changeVideo()">
            <option>Loading videos...</option>
        </select>
    </div>

    <video id="sync-video" controls preload="auto">
        <source src="./smjorRennsli1.mp4" type="video/mp4">
    </video>
    
    <p id="status" style="margin-top:20px; color: #ffab00;"></p>
</div>

<footer class="footer">
    <span>Developed by <a href="https://tarmo.uuu.ee/software/" target="_blank" rel="noopener">Tarmo Johannes</a></span>
    <a class="kofi-link" href="https://ko-fi.com/tarmojohannes" target="_blank" rel="noopener">
        <!-- <span>Buy me a coffee</span> -->
        <img class="kofi-logo" src="./bmc-logo-for-dark.svg" alt="Buy me a coffee">
    </a>
</footer>

<script>
    const video = document.getElementById('sync-video');
    const status = document.getElementById('status');
    let peer = null; 
    let conn = null;
    let latency = 0;
    const videoStorageKey = 'videosync-last-video';

    function hideQR() {
        document.getElementById('qrcode-container').classList.add('hidden');
        document.querySelector('.qr-toggle-link').classList.remove('hidden');
    }

    function toggleQR() {
        document.getElementById('qrcode-container').classList.remove('hidden');
        document.querySelector('.qr-toggle-link').classList.add('hidden');
    }

    // --- VIDEO SELECTION ---
    function getStoredVideo() {
        return localStorage.getItem(videoStorageKey);
    }

    function setStoredVideo(videoFile) {
        localStorage.setItem(videoStorageKey, videoFile);
    }

    function loadVideoList() {
        console.log('Loading video list...');
        fetch('?action=get_videos')  // Changed to use query parameter
            .then(response => {
                return response.text().then(text => {
                    try {
                        return JSON.parse(text);
                    } catch (e) {
                        console.error('JSON parse error:', e);
                        console.error('Response text that failed to parse:', text);
                        throw new Error('Invalid JSON response: ' + text.substring(0, 100));
                    }
                });
            })
            .then(videos => {
                console.log('Parsed videos:', videos);
                const select = document.getElementById('video-select');
                select.innerHTML = '';
                
                if (!Array.isArray(videos) || videos.length === 0) {
                    select.innerHTML = '<option>No videos found</option>';
                    return;
                }
                
                videos.forEach(videoFile => {
                    const option = document.createElement('option');
                    option.value = videoFile;
                    option.textContent = videoFile;
                    select.appendChild(option);
                });

                const storedVideo = getStoredVideo();
                if (storedVideo && videos.includes(storedVideo)) {
                    select.value = storedVideo;

                    const currentSource = video.querySelector('source');
                    if (!currentSource.src.endsWith(storedVideo)) {
                        currentSource.src = './' + storedVideo;
                        video.load();
                    }
                }
                console.log('Video list loaded successfully');
            })
            .catch(err => {
                console.error('Failed to load videos:', err);
                status.innerText = 'Error: ' + err.message;
                document.getElementById('video-select').innerHTML = '<option>Error loading videos</option>';
            });
    }

    function changeVideo() {
        const selectedVideo = document.getElementById('video-select').value;
        const currentTime = video.currentTime;
        const wasPlaying = !video.paused;

        setStoredVideo(selectedVideo);
        
        // Update video source
        video.querySelector('source').src = './' + selectedVideo;
        video.load();
        video.currentTime = currentTime;
        
        if (wasPlaying) {
            video.play();
        }
        
        // Notify peer about video change
        if (conn && conn.open) {
            conn.send({ 
                type: 'VIDEO_CHANGE', 
                videoFile: selectedVideo,
                time: currentTime,
                playing: wasPlaying
            });
        }
    }

    // Load video list on page load
    window.addEventListener('load', loadVideoList);

    function measureLatency() {
        if (!conn || !conn.open) return;
        
        const start = performance.now();
        // Send a ping to the other peer
        conn.send({ type: 'PING', sentAt: start });
    }

    // --- HOST LOGIC ---
    function startAsHost() {
        document.getElementById('setup-ui').classList.add('hidden');
        document.getElementById('host-ui').classList.remove('hidden');
        peer = new Peer();

        peer.on('open', (id) => {
            document.getElementById('my-id').innerText = id;
            console.log("Peer ID:", id);
            new QRCode(document.getElementById("qrcode"), id); // Generate QR
        });

        peer.on('connection', (connection) => {
            conn = connection;
            initSync();
            status.innerText = "Connected with Client";

        });
    }

    // --- CLIENT LOGIC ---
    function startAsClient() {
        document.getElementById('setup-ui').classList.add('hidden');
        document.getElementById('client-ui').classList.remove('hidden');

        peer = new Peer();

        const html5QrCode = new Html5Qrcode("reader");
        html5QrCode.start(
            { facingMode: "environment" }, 
            { fps: 10, qrbox: { width: 250, height: 250 } },
            (decodedText) => {
                // When QR is scanned:
                html5QrCode.stop();
                document.getElementById('client-ui').classList.add('hidden');
                console.log("Decoded QR:", decodedText);
                conn = peer.connect(decodedText);
                initSync();
                status.innerText = "Connected to Host!";
            }
        ).catch(err => console.error("Camera error:", err));
    }

    // --- SYNC CORE ---
    function initSync() {
        conn.on('data', (data) => {
            if (data.type === 'PING') {
                conn.send({ type: 'PONG', sentAt: data.sentAt });
            } 
            else if (data.type === 'PONG') {
                const end = performance.now();
                latency = (end - data.sentAt) / 2 / 1000; // Convert to seconds
                console.log(`Measured Latency: ${latency.toFixed(3)}s`);
            } 
            else if (data.type === 'SYNC') {
                // Apply the latency compensation!
                const adjustedTargetTime = data.time + latency;
                const diff = Math.abs(video.currentTime - adjustedTargetTime);

                if (diff > 0.5) {
                    // Large drift: Hard jump
                    video.currentTime = adjustedTargetTime;
                } else if (diff > 0.05) {
                    // Tiny drift: Slightly speed up/slow down to catch up (transparent to user)
                    video.playbackRate = (video.currentTime < adjustedTargetTime) ? 1.05 : 0.95;
                } else {
                    video.playbackRate = 1.0;
                }

                data.playing ? video.play() : video.pause();
            }
            else if (data.type === 'VIDEO_CHANGE') {
                // Update video source when peer changes video
                const select = document.getElementById('video-select');
                select.value = data.videoFile;

                setStoredVideo(data.videoFile);
                
                video.querySelector('source').src = './' + data.videoFile;
                video.load();
                video.currentTime = data.time;
                
                if (data.playing) {
                    video.play();
                }
            }
        });

        // const sync = () => {
        //     if (conn && conn.open) {
        //         conn.send({ type: 'SYNC', time: video.currentTime, playing: !video.paused });
        //     }
        // };
        
        // 2. Start heartbeat to keep latency data fresh
        setInterval(measureLatency, 3000);

        // 3. Broadcast changes
        const broadcast = () => {
            if (conn && conn.open) {
                conn.send({ 
                    type: 'SYNC', 
                    time: video.currentTime, 
                    playing: !video.paused 
                });
            }
        };

        video.onplay = broadcast;
        video.onpause = broadcast;
        video.onseeking = broadcast;
    
    }
</script>
</body>
</html>