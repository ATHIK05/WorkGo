const crypto = require("crypto");
const { generateAndSignC2paManifest, verifyManifestById } = require("../src/services/c2pa_signer");

describe("C2PA Content Authenticity Pipeline", () => {
  test("generates authentic C2PA manifest with worker identity and hash assertions", async () => {
    const rawImage = Buffer.from("workgo_mock_camera_image_bytes_2026", "utf8");
    const rawHash = crypto.createHash("sha256").update(rawImage).digest("hex");

    const manifest = await generateAndSignC2paManifest({
      workerId: "w_artisan_99",
      artisanName: "Selvaraj K.",
      trade: "Electrical",
      assetSha256: rawHash,
      base64Data: rawImage.toString("base64"),
      attestationToken: "mock_play_integrity_token_valid",
    });

    expect(manifest.manifestId).toContain("c2pa_urn_uuid_");
    expect(manifest.workerId).toBe("w_artisan_99");
    expect(manifest.artisanName).toBe("Selvaraj K.");
    expect(manifest.assetSha256).toBe(rawHash);
    expect(manifest.signature).toContain("RSA-PSS-SHA256:");
    expect(manifest.isAuthentic).toBe(true);

    const identityAssertion = manifest.assertions.find((a) => a.label === "workgo.artisan.identity");
    expect(identityAssertion).toBeDefined();
    expect(identityAssertion.data.workerId).toBe("w_artisan_99");
    expect(identityAssertion.data.kycVerified).toBe(true);

    const hashAssertion = manifest.assertions.find((a) => a.label === "c2pa.hash.data");
    expect(hashAssertion).toBeDefined();
    expect(hashAssertion.data.hash).toBe(rawHash);
  });

  test("rejects when raw image hash does not match claimed SHA-256 digest", async () => {
    const rawImage = Buffer.from("real_image_bytes", "utf8");
    const tamperedHash = "0000000000000000000000000000000000000000000000000000000000000000";

    await expect(
      generateAndSignC2paManifest({
        workerId: "w_artisan_99",
        artisanName: "Selvaraj K.",
        trade: "Electrical",
        assetSha256: tamperedHash,
        base64Data: rawImage.toString("base64"),
      })
    ).rejects.toThrow("C2PA Hash Mismatch");
  });

  test("public verification returns authentic provenance record", async () => {
    const verified = await verifyManifestById("c2pa_urn_uuid_demo_test");
    expect(verified.isAuthentic).toBe(true);
    expect(verified.signingAuthority).toBeDefined();
  });
});
