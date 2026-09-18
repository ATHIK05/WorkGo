const matchRouter = require("../src/routes/match");
const { calculateStandbyScore } = matchRouter;

describe("Fair Worker Allocation & Standby Scoring", () => {
  describe("calculateStandbyScore Formula", () => {
    test("grants idle unassigned worker higher score over recently assigned worker", () => {
      const now = new Date();
      const justAssigned = new Date(now.getTime() - 10 * 60 * 1000); // 10 minutes ago
      const assignedYesterday = new Date(now.getTime() - 25 * 60 * 60 * 1000); // 25 hours ago

      const idleWorker = {
        avgRating: 4.5,
        fairnessScore: 1.0,
        lastAssignedAt: assignedYesterday,
      };

      const busyWorker = {
        avgRating: 4.8, // higher rating
        fairnessScore: 0.6, // lower fairness due to prior assignments
        lastAssignedAt: justAssigned, // assigned 10 mins ago
      };

      const idleScore = calculateStandbyScore(idleWorker, 2.0);
      const busyScore = calculateStandbyScore(busyWorker, 2.0);

      // Idle worker should have a decisively higher standbyScore despite slightly lower rating
      expect(idleScore).toBeGreaterThan(busyScore);
    });

    test("rewards proximity appropriately", () => {
      const worker = {
        avgRating: 4.5,
        fairnessScore: 1.0,
        lastAssignedAt: null,
      };

      const closeScore = calculateStandbyScore(worker, 1.0);
      const farScore = calculateStandbyScore(worker, 5.0);

      expect(closeScore).toBeGreaterThan(farScore);
    });

    test("recency penalty decays as hours pass", () => {
      const now = new Date();
      const worker0h = {
        avgRating: 4.5,
        fairnessScore: 1.0,
        lastAssignedAt: now,
      };
      const worker3h = {
        avgRating: 4.5,
        fairnessScore: 1.0,
        lastAssignedAt: new Date(now.getTime() - 3 * 3600 * 1000),
      };
      const worker12h = {
        avgRating: 4.5,
        fairnessScore: 1.0,
        lastAssignedAt: new Date(now.getTime() - 12 * 3600 * 1000),
      };

      const score0 = calculateStandbyScore(worker0h, 2.0);
      const score3 = calculateStandbyScore(worker3h, 2.0);
      const score12 = calculateStandbyScore(worker12h, 2.0);

      expect(score3).toBeGreaterThan(score0);
      expect(score12).toBeGreaterThan(score3);
    });

    test("omits proximity component when distanceKm is null (regional standby allocation)", () => {
      const idleWorker = {
        avgRating: 4.5,
        fairnessScore: 1.0,
        lastAssignedAt: null,
      };

      const busyWorker = {
        avgRating: 5.0,
        fairnessScore: 0.5,
        lastAssignedAt: new Date(Date.now() - 30 * 60 * 1000), // 30m ago
      };

      // When distanceKm is null, proximity is 0.
      // idleWorker score: 0 + (1.0 * 40) + (4.5 / 5 * 20) - 0 = 40 + 18 = 58.0
      const scoreNullDist = calculateStandbyScore(idleWorker, null);
      expect(scoreNullDist).toBe(58.0);

      // Busy worker with null distance:
      // 0 + (0.5 * 40) + (5.0 / 5 * 20) - (exp(-0.5/6) * 25) = 20 + 20 - 23.0 = ~17.0
      const busyNullDist = calculateStandbyScore(busyWorker, null);
      expect(busyNullDist).toBeLessThan(scoreNullDist);

      // Omitting parameter entirely defaults to distanceKm = null
      expect(calculateStandbyScore(idleWorker)).toBe(58.0);
    });
  });
});
