import { Socket, Server } from 'socket.io';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Debounce save helper (simple in-memory for now, can be robustified)
const saveQueue: { [roomId: string]: NodeJS.Timeout } = {};

export const handleSocket = (socket: Socket, io: Server) => {
    console.log('User connected:', socket.id);

    socket.on('join_room', async (roomId: string) => {
        socket.join(roomId);
        console.log(`User ${socket.id} joined room ${roomId}`);

        // Load existing content
        try {
            let room = await prisma.room.findUnique({ where: { slug: roomId } });
            if (!room) {
                room = await prisma.room.create({
                    data: {
                        slug: roomId,
                        content: ''
                    }
                });
            }
            socket.emit('load_content', room.content);
        } catch (e) {
            console.error("Error loading room:", e);
        }
    });

    socket.on('text_change', (data: { roomId: string, content: string }) => {
        // Broadcast to others in the room
        socket.to(data.roomId).emit('text_update', data.content);

        // Save to DB (debounced)
        if (saveQueue[data.roomId]) {
            clearTimeout(saveQueue[data.roomId]);
        }

        saveQueue[data.roomId] = setTimeout(async () => {
            try {
                await prisma.room.update({
                    where: { slug: data.roomId },
                    data: { content: data.content }
                });
                console.log(`Saved content for room ${data.roomId}`);
            } catch (e) {
                console.error("Error saving content:", e);
            }
        }, 500); // 500ms debounce
    });

    socket.on('disconnect', () => {
        console.log('User disconnected:', socket.id);
    });
};
