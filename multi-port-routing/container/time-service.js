const http = require('http');
const port = 8081;

const server = http.createServer((req, res) => {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({
        currentTime: new Date().toISOString()
    }));
});

server.listen(port, '0.0.0.0', () => {
    console.log(`Time service running at http://0.0.0.0:${port}/`);
});
