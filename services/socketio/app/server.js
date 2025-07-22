const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');

const app = express();
const server = createServer(app);

// Environment variables
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';
const CORS_ORIGINS = process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',') : ['http://localhost:3000'];

// Supabase configuration
const SUPABASE_URL = process.env.SUPABASE_URL || 'http://localhost:8000';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || '';

let supabase = null;
if (SUPABASE_ANON_KEY) {
  supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

// CORS configuration
app.use(cors({
  origin: CORS_ORIGINS,
  credentials: true
}));

// Socket.io configuration
const io = new Server(server, {
  cors: {
    origin: CORS_ORIGINS,
    credentials: true
  },
  transports: ['websocket', 'polling']
});

// Express routes
app.get('/', (req, res) => {
  res.json({
    service: 'Socket.io Server',
    status: 'running',
    environment: NODE_ENV,
    port: PORT,
    clients: io.engine.clientsCount,
    version: require('./package.json').version
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    clients: io.engine.clientsCount
  });
});

app.get('/stats', (req, res) => {
  res.json({
    connectedClients: io.engine.clientsCount,
    rooms: Array.from(io.sockets.adapter.rooms.keys()),
    uptime: process.uptime(),
    environment: NODE_ENV
  });
});

// Socket.io connection handling
io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id}`);
  
  // Join a room
  socket.on('join-room', (room) => {
    socket.join(room);
    console.log(`Client ${socket.id} joined room: ${room}`);
    socket.emit('joined-room', room);
    socket.to(room).emit('user-joined', socket.id);
  });

  // Leave a room
  socket.on('leave-room', (room) => {
    socket.leave(room);
    console.log(`Client ${socket.id} left room: ${room}`);
    socket.emit('left-room', room);
    socket.to(room).emit('user-left', socket.id);
  });

  // Handle messages
  socket.on('message', (data) => {
    console.log(`Message from ${socket.id}:`, data);
    
    if (data.room) {
      // Send to specific room
      socket.to(data.room).emit('message', {
        ...data,
        from: socket.id,
        timestamp: new Date().toISOString()
      });
    } else {
      // Broadcast to all clients
      socket.broadcast.emit('message', {
        ...data,
        from: socket.id,
        timestamp: new Date().toISOString()
      });
    }
  });

  // Handle real-time data updates
  socket.on('data-update', (data) => {
    console.log(`Data update from ${socket.id}:`, data);
    
    // Broadcast data update to all clients in the same room
    if (data.room) {
      socket.to(data.room).emit('data-updated', {
        ...data,
        from: socket.id,
        timestamp: new Date().toISOString()
      });
    }
  });

  // Handle Supabase real-time subscriptions
  socket.on('subscribe-table', (tableName) => {
    if (supabase) {
      console.log(`Client ${socket.id} subscribing to table: ${tableName}`);
      
      // This is a simplified example - in production you'd want to manage subscriptions more carefully
      const subscription = supabase
        .channel(`public:${tableName}`)
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: tableName
        }, (payload) => {
          socket.emit('table-change', {
            table: tableName,
            event: payload.eventType,
            data: payload.new || payload.old,
            timestamp: new Date().toISOString()
          });
        })
        .subscribe();

      // Store subscription for cleanup
      socket.supabaseSubscriptions = socket.supabaseSubscriptions || [];
      socket.supabaseSubscriptions.push(subscription);
    }
  });

  // Handle disconnection
  socket.on('disconnect', (reason) => {
    console.log(`Client disconnected: ${socket.id}, reason: ${reason}`);
    
    // Clean up Supabase subscriptions
    if (socket.supabaseSubscriptions) {
      socket.supabaseSubscriptions.forEach(sub => {
        supabase.removeChannel(sub);
      });
    }
  });

  // Send welcome message
  socket.emit('welcome', {
    message: 'Connected to Socket.io server',
    socketId: socket.id,
    timestamp: new Date().toISOString()
  });
});

// Error handling
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

// Start server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Socket.io server running on port ${PORT}`);
  console.log(`📡 Environment: ${NODE_ENV}`);
  console.log(`🔗 CORS origins: ${CORS_ORIGINS.join(', ')}`);
  if (supabase) {
    console.log(`🟢 Supabase connected: ${SUPABASE_URL}`);
  } else {
    console.log(`🟡 Supabase not configured (missing ANON_KEY)`);
  }
});
