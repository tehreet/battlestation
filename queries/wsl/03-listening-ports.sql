-- listening_ports — sockets in LISTEN state inside WSL
SELECT * FROM listening_ports ORDER BY port, protocol;
