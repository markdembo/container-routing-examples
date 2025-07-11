const WebSocket = require('ws');
const port = 8082;

const wss = new WebSocket.Server({ port, host: '0.0.0.0' });

wss.on('connection', (ws) => {
    console.log('New WebSocket client connected');
    
    // Send initial welcome message
    ws.send(JSON.stringify({ type: 'connection', message: 'Connected to WebSocket server' }));
    
    // Set up interval to send test data every 3 seconds
    const interval = setInterval(() => {
        const testData = {
            timestamp: new Date().toISOString(),
            data: {
                value: Math.random() * 100,
                status: ['active', 'inactive', 'pending'][Math.floor(Math.random() * 3)]
            }
        };
        
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(testData));
        } else {
            clearInterval(interval);
        }
    }, 3000);
    
    // Clean up on client disconnect
    ws.on('close', () => {
        console.log('Client disconnected');
        clearInterval(interval);
    });
    
    ws.on('error', (error) => {
        console.error('WebSocket error:', error);
        clearInterval(interval);
    });
});

console.log(`WebSocket server running at ws://0.0.0.0:${port}/`);
