const documentsRouter = require("../src/routes/documents");

describe("Encrypted Documents Route (AES-256-CBC)", () => {
  const getPostHandler = () => {
    const layer = documentsRouter.stack.find(
      (l) => l.route && l.route.path === "/upload" && l.route.methods.post
    );
    return layer.route.stack[0].handle;
  };

  const getGetHandler = () => {
    const layer = documentsRouter.stack.find(
      (l) => l.route && l.route.path === "/:workerId/:docId" && l.route.methods.get
    );
    return layer.route.stack[0].handle;
  };

  test("accepts and encrypts welfareCertificate, welfareInjuryPhoto, and welfareHospitalRecord", async () => {
    const postHandler = getPostHandler();
    const getHandler = getGetHandler();

    const welfareDocTypes = ["welfareCertificate", "welfareInjuryPhoto", "welfareHospitalRecord"];

    for (const docType of welfareDocTypes) {
      let storedDoc = null;
      const samplePlaintext = `Confidential medical information for ${docType}: Doctor Dr. Ram, Apollo Hospital`;
      const base64Data = Buffer.from(samplePlaintext, "utf8").toString("base64");

      const mockDocRef = {
        id: `mock_doc_${docType}_123`,
        set: jest.fn().mockImplementation((data) => {
          storedDoc = data;
          return Promise.resolve();
        }),
        get: jest.fn().mockImplementation(() =>
          Promise.resolve({
            exists: true,
            data: () => storedDoc,
          })
        ),
      };

      const mockDb = {
        collection: jest.fn().mockImplementation((col) => {
          if (col === "workers") {
            return {
              doc: jest.fn().mockReturnValue({
                collection: jest.fn().mockReturnValue({
                  doc: jest.fn().mockReturnValue(mockDocRef),
                }),
                get: jest.fn().mockResolvedValue({
                  exists: true,
                  data: () => ({ userId: "worker_u1" }),
                }),
              }),
            };
          }
          if (col === "users") {
            return {
              doc: jest.fn().mockReturnValue({
                get: jest.fn().mockResolvedValue({
                  exists: true,
                  data: () => ({ role: "admin" }),
                }),
              }),
            };
          }
          return { doc: jest.fn().mockReturnValue({ get: jest.fn(), set: jest.fn() }) };
        }),
      };

      // 1. Test POST /upload
      const reqPost = {
        body: {
          workerId: "worker_01",
          docType,
          base64Data,
          fileName: `${docType}.pdf`,
        },
        user: { uid: "worker_01" },
        db: mockDb,
      };

      let postResData = null;
      const resPost = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn().mockImplementation((data) => {
          postResData = data;
        }),
      };

      await postHandler(reqPost, resPost);

      expect(postResData).toBeDefined();
      expect(postResData.success).toBe(true);
      expect(postResData.docId).toBe(`mock_doc_${docType}_123`);

      // Verify AES-256-CBC encryption: stored encryptedData must NOT match raw base64
      expect(storedDoc).toBeDefined();
      expect(storedDoc.docType).toBe(docType);
      expect(storedDoc.iv).toBeDefined();
      expect(storedDoc.encryptedData).toBeDefined();
      expect(storedDoc.encryptedData).not.toEqual(base64Data);

      // 2. Test GET /:workerId/:docId
      const reqGet = {
        params: { workerId: "worker_01", docId: postResData.docId },
        user: { uid: "admin_uid" },
        db: mockDb,
      };

      let getResData = null;
      const resGet = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn().mockImplementation((data) => {
          getResData = data;
        }),
      };

      await getHandler(reqGet, resGet);

      expect(getResData).toBeDefined();
      expect(getResData.docType).toBe(docType);
      expect(getResData.base64Data).toBe(base64Data);

      const decryptedUtf8 = Buffer.from(getResData.base64Data, "base64").toString("utf8");
      expect(decryptedUtf8).toBe(samplePlaintext);
    }
  });

  test("rejects unknown docType with 400 Bad Request", async () => {
    const postHandler = getPostHandler();

    const req = {
      body: {
        workerId: "worker_01",
        docType: "unauthorized_malicious_type",
        base64Data: "c29tZV9kYXRh",
      },
      user: { uid: "worker_01" },
      db: {},
    };

    let statusCalled = null;
    let jsonCalled = null;
    const res = {
      status: jest.fn().mockImplementation((code) => {
        statusCalled = code;
        return res;
      }),
      json: jest.fn().mockImplementation((data) => {
        jsonCalled = data;
      }),
    };

    await postHandler(req, res);

    expect(statusCalled).toBe(400);
    expect(jsonCalled.error).toContain("Invalid docType");
  });

  test("rejects unauthorized non-owner non-admin GET with 403 Forbidden", async () => {
    const getHandler = getGetHandler();

    const mockDb = {
      collection: jest.fn().mockImplementation((col) => {
        if (col === "users") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({ role: "customer" }),
              }),
            }),
          };
        }
        if (col === "workers") {
          return {
            doc: jest.fn().mockReturnValue({
              get: jest.fn().mockResolvedValue({
                exists: true,
                data: () => ({ userId: "worker_owner_uid" }),
              }),
            }),
          };
        }
        return { doc: jest.fn().mockReturnValue({ get: jest.fn() }) };
      }),
    };

    const req = {
      params: { workerId: "worker_owner_uid", docId: "doc_123" },
      user: { uid: "stranger_attacker_uid" },
      db: mockDb,
    };

    let statusCalled = null;
    const res = {
      status: jest.fn().mockImplementation((code) => {
        statusCalled = code;
        return res;
      }),
      json: jest.fn(),
    };

    await getHandler(req, res);

    expect(statusCalled).toBe(403);
  });
});
