/*jshint esversion: 9 */

const http = require('http');

const hostname = 'localhost';
const port = 80;
const agent = new http.Agent({ keepAlive: true, maxSockets: 50 });

const server = http.createServer((req, res) => {
    const {
        url,
        method,
        headers: {
            host,
            ...headers
        }
    } = req;
    const options = {
        path: url,
        hostname,
        port,
        method,
        headers,
        agent
    };
    const clientReq = http.request(options, (clientRes) => {
        clientRes.on('data', (chunk) => {
            res.write(chunk);
        });
        clientRes.on('end', (data) => {
            res.end(data);
        });
    });
    clientReq.on('error', (e) => {
        console.error(`problem with request: ${e.message}`);
    });
    req.on('data', (chunk) => {
        clientReq.write(chunk);
    });
    req.on('end', () => {
        clientReq.end();
    });
});
server.on('clientError', (err, socket) => {
    socket.end('HTTP/1.1 400 Bad Request\r\n\r\n');
});
server.listen(8000);