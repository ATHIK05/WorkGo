const http = require('http');

const LAN_IP = '192.168.1.7';
const HTTP_PORT = 8080;

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

const server = http.createServer((req, res) => {
  console.log(`[HTTP Provisioning] Request from ${req.socket.remoteAddress} for ${req.url}`);
  res.writeHead(200, { 'Content-Type': 'application/xml', 'Access-Control-Allow-Origin': '*' });
  res.end(xmlConfig);
});

server.listen(HTTP_PORT, '0.0.0.0', () => {
  console.log(`Linphone Auto-Provisioning active at: http://${LAN_IP}:${HTTP_PORT}/linphone.xml`);
});
