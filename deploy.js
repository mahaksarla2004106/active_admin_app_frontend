const fs = require('fs');
const https = require('https');
const path = require('path');
const archiver = require('archiver');

const token = 'nfp_KZAFcvSXFj7sLKMrCzqtTvcqW8MddVH79df1';
const siteId = 'activefrontend.netlify.app';

const zipPath = path.join(__dirname, 'build.zip');
const output = fs.createWriteStream(zipPath);
const archive = archiver('zip', { zlib: { level: 9 } });

output.on('close', function() {
    console.log(archive.pointer() + ' total bytes zipped');
    console.log('Uploading to Netlify...');

    const fileStream = fs.createReadStream(zipPath);
    
    const options = {
        hostname: 'api.netlify.com',
        port: 443,
        path: `/api/v1/sites/${siteId}/deploys`,
        method: 'POST',
        headers: {
            'Content-Type': 'application/zip',
            'Authorization': `Bearer ${token}`,
            'Content-Length': fs.statSync(zipPath).size
        }
    };

    const req = https.request(options, (res) => {
        console.log(`STATUS: ${res.statusCode}`);
        let body = '';
        res.on('data', (chunk) => body += chunk);
        res.on('end', () => {
            console.log('Response:', body);
            // Delete zip
            fs.unlinkSync(zipPath);
        });
    });

    req.on('error', (e) => {
        console.error(`Problem with request: ${e.message}`);
    });

    fileStream.pipe(req);
});

archive.on('error', function(err) {
    throw err;
});

archive.pipe(output);
archive.directory(path.join(__dirname, 'build/web'), false);
archive.finalize();
