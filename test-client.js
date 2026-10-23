// Quick test script using Node.js (already installed on your PC)
// Sends simulated joystick circles and button presses to AirSense Server over UDP
const dgram = require('dgram');
const client = dgram.createSocket('udp4');

const PORT = 9050;
const HOST = '127.0.0.1';

console.log('Sending AirSense discovery ping to', HOST + ':' + PORT);

// 1. Send Discovery Ping
const ping = Buffer.from([0x41, 0x49, 0x52, 0x53, 0x01]);
client.send(ping, PORT, HOST);

// Listen for feedback / pong
client.on('message', (msg) => {
  if (msg[4] === 0x02) {
    const name = msg.subarray(6).toString();
    console.log(`✓ Discovered AirSense Host: "${name}"`);
    console.log('Now streaming simulated inputs for 10 seconds...');
    console.log('👉 Open "joy.cpl" (Win + R -> joy.cpl) to watch the controller move in real-time!');
    startInputLoop();
  } else if (msg[4] === 0x20) {
    console.log(`[Rumble from PC Game] Heavy: ${msg[5]}, Light: ${msg[6]}, Color: RGB(${msg[7]}, ${msg[8]}, ${msg[9]})`);
  }
});

let angle = 0;
function startInputLoop() {
  const interval = setInterval(() => {
    angle += 0.05;
    const packet = Buffer.alloc(36);

    // Magic "AIRS"
    packet[0] = 0x41; packet[1] = 0x49; packet[2] = 0x52; packet[3] = 0x53;
    packet[4] = 0x10; // InputFrame

    // Buttons: toggle Cross (0x01) every 2 seconds
    const crossPressed = Math.sin(angle * 2) > 0.5;
    packet.writeUInt32LE(crossPressed ? 0x01 : 0x00, 5);

    // Left Stick: smooth circle
    const lx = Math.round(Math.cos(angle) * 30000);
    const ly = Math.round(Math.sin(angle) * 30000);
    packet.writeInt16LE(lx, 9);
    packet.writeInt16LE(ly, 11);

    // Triggers: oscillating pull
    const trigger = Math.round((Math.sin(angle) + 1) * 127);
    packet[17] = trigger; // L2
    packet[18] = 255 - trigger; // R2

    client.send(packet, PORT, HOST);
  }, 16); // ~60 Hz

  setTimeout(() => {
    clearInterval(interval);
    console.log('✓ Test finished! Controller state reset.');
    client.close();
  }, 10000);
}
