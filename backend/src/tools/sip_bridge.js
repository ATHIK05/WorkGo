/**
 * WorkGo SIP Bridge (Windows Host -> WSL Asterisk)
 * 
 * Proxies SIP UDP packets between the local Wi-Fi interface (Windows host: 192.168.1.7:5060)
 * and the Asterisk PBX running inside WSL2.
 * Also serves remote auto-configuration XML for Linphone on HTTP port 8080.
 */

const dgram = require('dgram');
const http = require('http');
const { execSync } = require('child_process');

function getWslIp() {
  try {
    const stdout = execSync('wsl hostname -I', { encoding: 'utf8' }).trim();
    const ip = stdout.split(/\s+/)[0];
    if (ip && ip.includes('.')) return ip;
  } catch (err) {
    console.error('Could not detect WSL IP automatically:', err.message);
  }
  return '172.31.173.133'; // fallback
}

const WSL_IP = getWslIp();
const SIP_PORT = 5060;
const HTTP_PORT = 8080;
const LAN_IP = '192.168.1.7';

// ── UDP SIP Proxy ────────────────────────────────────────────────────────────
const server = dgram.createSocket('udp4');
const clients = new Map(); // key: branch, val: { address, port, originalVia }
let lastClient = null;

server.on('error', (err) => {
  console.error('[SIP Bridge Error]', err);
});

server.on('message', (msg, rinfo) => {
  const isFromWsl = rinfo.address === WSL_IP || rinfo.address === '127.0.0.1';

  if (!isFromWsl) {
    // Packet from phone / Linphone -> Forward to Asterisk in WSL
    lastClient = { address: rinfo.address, port: rinfo.port };
    let str = msg.toString('utf8');
    const firstLine = str.split('\r\n')[0];
    console.log(`[📱 Linphone -> Asterisk] RAW:\n${str}\n---END RAW---`);

    // Prepend a Via header pointing to the bridge so Asterisk replies to us
    const branch = 'z9hG4bK-' + Date.now() + '-' + Math.floor(Math.random() * 10000);
    clients.set(branch, { address: rinfo.address, port: rinfo.port });

    // Insert proxy Via header right before the first Via header
    const viaIndex = str.indexOf('Via:');
    if (viaIndex !== -1) {
      const proxyVia = `Via: SIP/2.0/UDP 172.31.160.1:5060;branch=${branch};rport\r\n`;
      str = str.slice(0, viaIndex) + proxyVia + str.slice(viaIndex);
    }

    const payload = Buffer.from(str, 'utf8');
    server.send(payload, SIP_PORT, WSL_IP, (err) => {
      if (err) console.error('Error forwarding to WSL:', err);
    });
  } else {
    // Reply from Asterisk in WSL -> Forward back to the phone
    let str = msg.toString('utf8');
    const firstLine = str.split('\r\n')[0];
    console.log(`[🖥️ Asterisk -> Linphone] ${firstLine}`);

    // Remove the proxy Via header we added earlier
    const match = str.match(/Via: SIP\/2\.0\/UDP 172\.31\.160\.1:5060;branch=([^;\r\n]+)[^\r\n]*\r\n/i);
    let target = lastClient;

    if (match) {
      const branch = match[1];
      if (clients.has(branch)) {
        target = clients.get(branch);
        clients.delete(branch);
      }
      str = str.replace(match[0], '');
    }

    if (target) {
      const payload = Buffer.from(str, 'utf8');
      server.send(payload, target.port, target.address, (err) => {
        if (err) console.error(`Error forwarding to ${target.address}:${target.port}:`, err);
        else console.log(`[Sent to Phone] -> ${target.address}:${target.port} (${firstLine})`);
      });
    }
  }
});

server.bind(SIP_PORT, '0.0.0.0', () => {
  console.log('====================================================');
  console.log('  WorkGo SIP Telephony Bridge (Active)');
  console.log(`  Listening on Windows LAN : 0.0.0.0:${SIP_PORT}`);
  console.log(`  Target WSL Asterisk IP   : ${WSL_IP}:${SIP_PORT}`);
  console.log('====================================================');
  console.log('Ready for Linphone on your mobile phone to connect!');
});

// ── HTTP Auto-Provisioning Server for Linphone ──────────────────────────────
const xmlConfig = `<?xml version="1.0" encoding="UTF-8"?>
<config xmlns="http://www.linphone.org/xsds/lpconfig.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <section name="proxy_default_values">
    <entry name="reg_proxy">&lt;sip:${LAN_IP}:5060;transport=udp&gt;</entry>
    <entry name="reg_route">&lt;sip:${LAN_IP}:5060;transport=udp&gt;</entry>
    <entry name="reg_identity">sip:workgo_26089@${LAN_IP}</entry>
    <entry name="reg_expires">3600</entry>
    <entry name="reg_sendregister">1</entry>
  </section>
  <section name="auth_info_default_values">
    <entry name="username">workgo_26089</entry>
    <entry name="password">workgoSecretPassword123</entry>
    <entry name="domain">${LAN_IP}</entry>
  </section>
</config>`;

const httpServer = http.createServer((req, res) => {
  console.log(`[HTTP Provisioning] Request from ${req.socket.remoteAddress} for ${req.url}`);
  res.writeHead(200, { 'Content-Type': 'application/xml' });
  res.end(xmlConfig);
});

httpServer.listen(HTTP_PORT, '0.0.0.0', () => {
  console.log(`  Auto-Provisioning URL    : http://${LAN_IP}:${HTTP_PORT}/linphone.xml`);
});
