import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import dotenv from 'dotenv';
import { handleSocket } from './socket/handler';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3010;

app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*", // Allow all for now, tighten for prod
        methods: ["GET", "POST"]
    }
});

io.on('connection', (socket) => {
    handleSocket(socket, io);
});

app.get('/', (req, res) => {
    res.send('MasterTexto Backend is running');
});

server.listen(PORT, () => {
    console.log(`[server] Running on port ${PORT}`);
});
