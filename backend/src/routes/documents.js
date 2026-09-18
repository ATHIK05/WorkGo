const express = require("express");
const crypto = require("crypto");
const router = express.Router();

const ALGO = "aes-256-cbc";
const KEY = Buffer.from(process.env.DOCUMENT_ENCRYPTION_KEY || "0".repeat(64), "hex");

/**
 * Validated document types for the encrypted document vault subcollection
 * workers/{workerId}/documents/{docId}.
 */
const ALLOWED_DOC_TYPES = [
  "doc_pcc",
  "pcc",
  "policeClearance",
  "welfareCertificate",
  "welfareInjuryPhoto",
  "welfareHospitalRecord",
];

function encrypt(base64Data) {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(ALGO, KEY, iv);
  const encrypted = Buffer.concat([
    cipher.update(Buffer.from(base64Data, "base64")),
    cipher.final(),
  ]);
  return { iv: iv.toString("hex"), data: encrypted.toString("base64") };
}

function decrypt(iv, encryptedData) {
  const decipher = crypto.createDecipheriv(ALGO, KEY, Buffer.from(iv, "hex"));
  const decrypted = Buffer.concat([
    decipher.update(Buffer.from(encryptedData, "base64")),
    decipher.final(),
  ]);
  return decrypted.toString("base64");
}

// POST /api/documents/upload — encrypt and store document in Firestore
router.post("/upload", async (req, res) => {
  try {
    const { workerId, docType, base64Data, fileName } = req.body;
    if (!workerId || !docType || !base64Data) {
      return res.status(400).json({ error: "workerId, docType, base64Data required" });
    }

    if (!ALLOWED_DOC_TYPES.includes(docType)) {
      return res.status(400).json({
        error: `Invalid docType "${docType}". Allowed types: ${ALLOWED_DOC_TYPES.join(", ")}`,
      });
    }

    // Size guard: base64 of 800KB = ~1.07MB; Firestore doc limit is 1MiB
    if (base64Data.length > 1_000_000) {
      return res.status(413).json({ error: "Document too large. Compress to under 800KB." });
    }

    const { iv, data } = encrypt(base64Data);
    const docRef = req.db
      .collection("workers")
      .doc(workerId)
      .collection("documents")
      .doc();

    await docRef.set({
      docType,
      fileName: fileName || `${docType}.dat`,
      iv,
      encryptedData: data,
      uploadedAt: new Date().toISOString(),
      uploadedBy: req.user.uid,
    });

    res.json({ success: true, docId: docRef.id, docType });
  } catch (e) {
    console.error("documents/upload error:", e);
    res.status(500).json({ error: "Upload failed" });
  }
});

// GET /api/documents/:workerId/:docId — decrypt and return (Admin or owning worker)
router.get("/:workerId/:docId", async (req, res) => {
  try {
    const { workerId, docId } = req.params;

    // Verify caller is admin or the owning worker / authorized proxy referrer
    const isOwner = req.user.uid === workerId;
    let isAdmin = false;
    const userDoc = await req.db.collection("users").doc(req.user.uid).get();
    if (userDoc.exists && userDoc.data().role === "admin") {
      isAdmin = true;
    }

    if (!isOwner && !isAdmin) {
      const workerDoc = await req.db.collection("workers").doc(workerId).get();
      const isProxyReferrer = workerDoc.exists && (
        workerDoc.data().proxyReferrerId === req.user.uid ||
        workerDoc.data().userId === req.user.uid
      );
      if (!isProxyReferrer) {
        return res.status(403).json({ error: "Admin or owner access required" });
      }
    }

    const doc = await req.db
      .collection("workers")
      .doc(workerId)
      .collection("documents")
      .doc(docId)
      .get();

    if (!doc.exists) return res.status(404).json({ error: "Document not found" });

    const { iv, encryptedData, docType, fileName, uploadedAt } = doc.data();
    const base64Data = decrypt(iv, encryptedData);

    res.json({ docType, fileName, base64Data, uploadedAt });
  } catch (e) {
    console.error("documents/get error:", e);
    res.status(500).json({ error: "Decryption failed" });
  }
});

module.exports = router;
