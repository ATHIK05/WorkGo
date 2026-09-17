const dgram = require('dgram');
const net = require('net');
const { execSync } = require('child_process');
const os = require('os');

// ── 0. Dynamic Network Detection ─────────────────────────────────────────────
function getWslIp() {
  try {
    const stdout = execSync('wsl hostname -I', { encoding: 'utf8' }).trim();
    const ip = stdout.split(/\s+/)[0];
    if (ip && ip.includes('.')) return ip;
  } catch (err) {
    console.error('Could not detect WSL IP automatically:', err.message);
  }
  return '172.31.173.133';
}

function getWslGateway() {
  try {
    const stdout = execSync('wsl ip route', { encoding: 'utf8' }).trim();
    const match = stdout.match(/default via ([0-9.]+)/);
    if (match) return match[1];
  } catch (err) {}
  return '172.31.160.1';
}

function getLanIp() {
  const ifaces = os.networkInterfaces();
  for (const name of Object.keys(ifaces)) {
    for (const iface of ifaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal && !iface.address.startsWith('172.31.') && !iface.address.startsWith('169.254.')) {
        return iface.address;
      }
    }
  }
  return '192.168.1.7';
}

const WSL_IP = getWslIp();
const GATEWAY_IP = getWslGateway();
const LAN_IP = getLanIp();
const SIP_PORT = 5060;

console.log('====================================================');
console.log('  WorkGo Advanced SIP & RTP Bridge (Production Ready)');
console.log('====================================================');
console.log(`  WSL Asterisk IP          : ${WSL_IP}`);
console.log(`  WSL Gateway (Windows)    : ${GATEWAY_IP}`);
console.log(`  Windows LAN / Wi-Fi IP   : ${LAN_IP}`);
console.log('====================================================');

// ── 1. Dynamic Multi-Session RTP Audio Proxy ──────────────────────────────────
// Maps Asterisk RTP Port -> UDP Socket
const rtpProxies = new Map();
// Maps Asterisk RTP Port -> { phoneIp, phoneRtpPort }
const rtpSessions = new Map();

function ensureRtpProxy(astRtpPort, phoneIp, phoneRtpPort) {
  let session = rtpSessions.get(astRtpPort);
  if (!session) {
    session = { phoneIp: phoneIp || null, phoneRtpPort: phoneRtpPort || null };
    rtpSessions.set(astRtpPort, session);
  } else {
    if (phoneIp) session.phoneIp = phoneIp;
    if (phoneRtpPort) session.phoneRtpPort = phoneRtpPort;
  }

  if (rtpProxies.has(astRtpPort)) {
    return rtpProxies.get(astRtpPort);
  }

  const socket = dgram.createSocket('udp4');

  socket.on('error', (err) => {
    console.error(`[RTP Proxy Port ${astRtpPort} Error]:`, err.message);
  });

  socket.on('message', (data, rinfo) => {
    const fromWsl = rinfo.address === WSL_IP || rinfo.address.startsWith('172.31.');

    if (fromWsl) {
      // Asterisk audio -> Destination Phone
      const current = rtpSessions.get(astRtpPort);
      if (current && current.phoneIp && current.phoneRtpPort) {
        socket.send(data, current.phoneRtpPort, current.phoneIp);
      }
    } else {
      // Phone audio/DTMF -> Asterisk
      // Dynamic NAT traversal: pinhole learning from phone's actual RTP packet
      const current = rtpSessions.get(astRtpPort);
      if (current) {
        current.phoneIp = rinfo.address;
        current.phoneRtpPort = rinfo.port;
      }
      socket.send(data, astRtpPort, WSL_IP);
    }
  });

  socket.bind(astRtpPort, '0.0.0.0', () => {
    console.log(`[🎙️ RTP Audio Proxy ACTIVE] 0.0.0.0:${astRtpPort} <-> Asterisk ${WSL_IP}:${astRtpPort} & Phone ${phoneIp || 'auto'}:${phoneRtpPort || 'auto'}`);
  });

  rtpProxies.set(astRtpPort, socket);

  // Auto-reap inactive RTP proxy after 5 minutes of call completion
  setTimeout(() => {
    try {
      socket.close();
      rtpProxies.delete(astRtpPort);
      rtpSessions.delete(astRtpPort);
    } catch (_) {}
  }, 300000);

  return socket;
}

// ── 2. TCP SIP Proxy ─────────────────────────────────────────────────────────
const tcpServer = net.createServer((clientSocket) => {
  const remote = `${clientSocket.remoteAddress}:${clientSocket.remotePort}`;
  console.log(`[📱 Phone -> Asterisk TCP] Connection from ${remote}`);

  const wslSocket = net.connect(SIP_PORT, WSL_IP, () => {
    clientSocket.pipe(wslSocket);
    wslSocket.pipe(clientSocket);
  });

  wslSocket.on('error', (err) => {
    console.error(`[TCP Proxy to WSL error]:`, err.message);
    clientSocket.destroy();
  });
  clientSocket.on('error', (err) => {
    console.error(`[TCP Client error]:`, err.message);
    wslSocket.destroy();
  });
});

tcpServer.listen(SIP_PORT, '0.0.0.0', () => {
  console.log(`  TCP SIP Proxy Listening  : 0.0.0.0:${SIP_PORT} -> ${WSL_IP}:${SIP_PORT}`);
});

// ── 3. Dynamic UDP SIP Proxy ─────────────────────────────────────────────────
const udpServer = dgram.createSocket('udp4');
const clients = new Map(); // branch -> { address, port }
const registeredEndpoints = new Map(); // username -> { address, port, lastSeen }
let lastClient = null;
let lastPhoneAudio = null;

udpServer.on('error', (err) => {
  console.error('[UDP Bridge Error]', err);
});

udpServer.on('message', (msg, rinfo) => {
  const isFromWsl = rinfo.address === WSL_IP || rinfo.address.startsWith('172.31.');

  if (!isFromWsl) {
    // ── Incoming from Phone ──────────────────────────────────────────────────
    lastClient = { address: rinfo.address, port: rinfo.port };
    let str = msg.toString('utf8');
    const firstLine = str.split('\r\n')[0];

    // Dynamically register phone endpoint from SIP headers (REGISTER / INVITE)
    const fromMatch = str.match(/From:\s*<sip:([^@>]+)@/i);
    const toMatch = str.match(/To:\s*<sip:([^@>]+)@/i);
    const username = (fromMatch && fromMatch[1]) || (toMatch && toMatch[1]);
    if (username && username !== '1000' && username !== 'asterisk') {
      registeredEndpoints.set(username, {
        address: rinfo.address,
        port: rinfo.port,
        lastSeen: Date.now(),
      });
      console.log(`[📌 Registered Endpoint] ${username} -> ${rinfo.address}:${rinfo.port}`);
    }

    // Detect SDP audio port from Phone INVITE or 200 OK
    const mMatch = str.match(/m=audio\s+(\d+)/i);
    if (mMatch) {
      const phoneRtpPort = parseInt(mMatch[1], 10);
      lastPhoneAudio = {
        phoneIp: rinfo.address,
        phoneRtpPort: phoneRtpPort,
      };
      console.log(`[📞 Audio Channel Announced] Phone ${rinfo.address}:${phoneRtpPort}`);

      // If answering an Asterisk outbound alert call (200 OK)
      if (str.startsWith('SIP/2.0 200 OK')) {
        for (const [astPort, sess] of rtpSessions.entries()) {
          if (!sess.phoneRtpPort || sess.phoneIp === rinfo.address) {
            sess.phoneIp = rinfo.address;
            sess.phoneRtpPort = phoneRtpPort;
            console.log(`[📞 Call Answered] Ast Port ${astPort} linked to Phone ${rinfo.address}:${phoneRtpPort}`);
          }
        }
      }
    }

    console.log(`\n[📱 Phone -> Asterisk UDP] ${firstLine} from ${rinfo.address}:${rinfo.port}`);

    // If this is an in-dialog request (ACK, BYE, CANCEL) referencing our LAN IP, rewrite to WSL IP
    if (str.startsWith('ACK ') || str.startsWith('BYE ') || str.startsWith('CANCEL ')) {
      str = str.replace(/^([A-Z]+\s+sip:[^@\s]+@)[0-9.]+/m, `$1${WSL_IP}`);
      str = str.replace(/^([A-Z]+\s+sip:)[0-9.]+/m, `$1${WSL_IP}`);
    }

    const isResponse = str.startsWith('SIP/2.0 ');

    if (!isResponse) {
      const branch = 'z9hG4bK-' + Date.now() + '-' + Math.floor(Math.random() * 10000);
      clients.set(branch, { address: rinfo.address, port: rinfo.port });

      // Prepend Proxy Via only to requests (responses must keep Asterisk transaction untouched)
      const viaIndex = str.indexOf('Via:');
      if (viaIndex !== -1) {
        const proxyVia = `Via: SIP/2.0/UDP ${GATEWAY_IP}:${SIP_PORT};branch=${branch};rport\r\n`;
        str = str.slice(0, viaIndex) + proxyVia + str.slice(viaIndex);
      }
    }

    const payload = Buffer.from(str, 'utf8');
    udpServer.send(payload, SIP_PORT, WSL_IP, (err) => {
      if (err) console.error('Error forwarding UDP to WSL:', err);
    });
  } else {
    // ── Incoming from Asterisk ───────────────────────────────────────────────
    let str = msg.toString('utf8');
    const firstLine = str.split('\r\n')[0];
    console.log(`\n[🖥️ Asterisk -> Phone UDP] ${firstLine}`);

    // 1. Check if this is a response matching our Proxy Via header
    const viaRegex = new RegExp(`Via:\\s*SIP\\/2\\.0\\/[^\\r\\n]*${GATEWAY_IP.replace(/\\./g, '\\.')}:5060[^\\r\\n]*\\r\\n`, 'i');
    const viaMatch = str.match(viaRegex);
    let target = null;

    if (viaMatch) {
      const branchMatch = viaMatch[0].match(/branch=([^;\r\n\s]+)/i);
      if (branchMatch) {
        const branch = branchMatch[1];
        if (clients.has(branch)) {
          target = clients.get(branch);
          setTimeout(() => clients.delete(branch), 60000);
        }
      }
      str = str.replace(viaMatch[0], '');
    }

    // 2. Outbound Asterisk requests (e.g. INVITE for booking alerts):
    // Dynamically route by callee username in registeredEndpoints
    if (!target) {
      const reqUriMatch = str.match(/^[A-Z]+\s+sip:([^@\s;]+)@/m);
      const toMatch = str.match(/To:\s*<sip:([^@>;]+)@/i);
      const callee = (reqUriMatch && reqUriMatch[1]) || (toMatch && toMatch[1]);

      if (callee && registeredEndpoints.has(callee)) {
        target = registeredEndpoints.get(callee);
        console.log(`[🎯 Dynamic Outbound Route] Endpoint '${callee}' -> ${target.address}:${target.port}`);
      }
    }

    // 3. Check for x-ast-orig-host parameter
    if (!target) {
      const origHostMatch = str.match(/x-ast-orig-host=([0-9.]+):(\d+)/i);
      if (origHostMatch) {
        target = { address: origHostMatch[1], port: parseInt(origHostMatch[2], 10) };
      }
    }

    // 4. Check for client Via (if non-internal)
    if (!target) {
      const clientViaMatch = str.match(/Via:\s*SIP\/2\.0\/UDP\s+([0-9.]+):(\d+)/i);
      if (clientViaMatch && !clientViaMatch[1].startsWith('172.31.') && !clientViaMatch[1].startsWith('127.0.')) {
        target = { address: clientViaMatch[1], port: parseInt(clientViaMatch[2], 10) };
      }
    }

    // 5. Fallback to last seen client
    if (!target && lastClient) {
      target = lastClient;
    }

    // Rewrite Request-URI destination for outbound calls to phone
    if (target && str.startsWith('INVITE ')) {
      str = str.replace(/^(INVITE\s+sip:[^@\s]+@)[0-9.]+(:\d+)?/m, `$1${target.address}:${target.port}`);
    }

    // ── REWRITE Asterisk Internal IP -> LAN IP so Phone can send ACK & Audio ─
    str = str.replace(/Contact:\s*<sip:([^@>]+@)?172\.31\.[0-9.]+:(\d+)>/gi, `Contact: <sip:$1${LAN_IP}:${SIP_PORT}>`);
    str = str.replace(/Contact:\s*<sip:172\.31\.[0-9.]+:(\d+)>/gi, `Contact: <sip:${LAN_IP}:${SIP_PORT}>`);

    const sdpIndex = str.indexOf('\r\n\r\n');
    if (sdpIndex !== -1) {
      let headers = str.slice(0, sdpIndex);
      let sdp = str.slice(sdpIndex + 4);

      if (sdp.includes('v=0')) {
        const mMatch = sdp.match(/m=audio\s+(\d+)/i);
        if (mMatch) {
          const astRtpPort = parseInt(mMatch[1], 10);
          if (lastPhoneAudio && lastPhoneAudio.phoneIp) {
            ensureRtpProxy(astRtpPort, lastPhoneAudio.phoneIp, lastPhoneAudio.phoneRtpPort);
          } else if (target) {
            ensureRtpProxy(astRtpPort, target.address, null);
          }
        }

        sdp = sdp.replace(/c=IN IP4 172\.31\.[0-9.]+/g, `c=IN IP4 ${LAN_IP}`);
        sdp = sdp.replace(/o=- (\d+) (\d+) IN IP4 172\.31\.[0-9.]+/g, `o=- $1 $2 IN IP4 ${LAN_IP}`);

        const newLen = Buffer.byteLength(sdp, 'utf8');
        headers = headers.replace(/Content-Length:\s*\d+/i, `Content-Length: ${newLen}`);

        str = headers + '\r\n\r\n' + sdp;
      }
    }

    if (target) {
      const payload = Buffer.from(str, 'utf8');
      udpServer.send(payload, target.port, target.address, (err) => {
        if (err) console.error(`Error forwarding to ${target.address}:${target.port}:`, err);
        else console.log(`[Sent to Phone UDP] -> ${target.address}:${target.port} (${firstLine})`);
      });
    } else {
      console.warn(`[⚠️ Warning] Could not resolve destination for Asterisk message: ${firstLine}`);
    }
  }
});

udpServer.bind(SIP_PORT, '0.0.0.0', () => {
  console.log(`  UDP SIP Proxy Listening  : 0.0.0.0:${SIP_PORT} -> ${WSL_IP}:${SIP_PORT}`);
  console.log('====================================================');
  console.log('WorkGo SIP Dual Bridge (UDP + TCP + RTP) is READY!');
  console.log('====================================================');
});
