const { verifyAadhaarOfflineKyc } = require("../src/services/aadhaar_xml_verifier");

describe("UIDAI Offline Aadhaar eKYC Verifier", () => {
  test("successfully extracts demographic data from valid XML payload", async () => {
    const sampleXml = `<?xml version="1.0" encoding="UTF-8"?>
<OfflinePaperlessKyc referenceId="123420260831120000000">
  <UidData>
    <Poi dob="1990-04-12" gender="M" name="Murugan Shanmugam" />
    <Poa careof="S/O Shanmugam" country="India" dist="Chennai" loc="T Nagar" pc="600017" state="Tamil Nadu" vtc="Chennai" />
    <Pht>/9j/4AAQSkZJRgABAQEASABIAAD...</Pht>
  </UidData>
  <Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
    <SignedInfo><SignatureValue>MOCK_VALID_UIDAI_SIG_VALUE</SignatureValue></SignedInfo>
  </Signature>
</OfflinePaperlessKyc>`;

    const base64Data = Buffer.from(sampleXml, "utf8").toString("base64");
    const result = await verifyAadhaarOfflineKyc({
      base64Data,
      shareCode: "4321",
      fileName: "offline_aadhaar.xml",
    });

    expect(result.verified).toBe(true);
    expect(result.name).toBe("Murugan Shanmugam");
    expect(result.dob).toBe("1990-04-12");
    expect(result.maskedAadhaar).toContain("XXXXXXXX");
    expect(result.hasValidSignature).toBe(true);
    expect(result.xmlSha256).toBeDefined();
  });

  test("rejects invalid share code length", async () => {
    const base64Data = Buffer.from("<xml></xml>", "utf8").toString("base64");
    await expect(
      verifyAadhaarOfflineKyc({
        base64Data,
        shareCode: "12", // Invalid: must be 4 digits
      })
    ).rejects.toThrow("Invalid 4-digit share code");
  });
});
