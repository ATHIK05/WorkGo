/**
 * WorkGo Master Cloud Functions Suite for Push Notifications
 * Supports dual deployment:
 * 1. Deployable to Firebase Cloud Functions (v2) / Google Cloud Functions
 * 2. Runnable as live reactive background listeners on Render Express backend
 */

const admin = require("firebase-admin");
const { NotificationEngine } = require("../services/notification_engine");

let notificationEngine;

function getEngine(db, messaging) {
  if (!notificationEngine) {
    notificationEngine = new NotificationEngine(db, messaging);
  }
  return notificationEngine;
}

// ─────────────────────────────────────────────────────────────────────────────
//  EVENT HANDLERS (Shared business logic between Cloud Functions & Render)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Triggered when a new booking is created (pending broadcast)
 */
async function handleBookingCreated(bookingId, bookingData, db, messaging) {
  const engine = getEngine(db, messaging);
  console.log(`[CloudFunction] onBookingCreated: Booking #${bookingId} for ${bookingData.serviceType}`);

  // 1. Alert customer that broadcast is active
  if (bookingData.customerId) {
    await engine.sendToUser(
      bookingData.customerId,
      "BOOKING_BROADCAST_STARTED",
      {
        category: bookingData.serviceType,
        amount: String(bookingData.amount || 0),
      },
      { bookingId }
    );
  }

  // 2. Broadcast to all nearby online verified workers matching the trade
  await engine.broadcastNewBookingToNearbyWorkers({
    id: bookingId,
    ...bookingData,
  });
}

/**
 * Triggered when a booking document changes state
 */
async function handleBookingUpdated(bookingId, beforeData, afterData, db, messaging) {
  const engine = getEngine(db, messaging);
  const oldStatus = beforeData.status;
  const newStatus = afterData.status;
  const oldBonus = beforeData.urgencyBonus || 0;
  const newBonus = afterData.urgencyBonus || 0;

  console.log(`[CloudFunction] onBookingUpdated: Booking #${bookingId} status: ${oldStatus} -> ${newStatus}`);

  // 1. Customer raised Urgency Fare Boost
  if (newBonus > oldBonus && newStatus === "pending") {
    const diff = newBonus - oldBonus;
    console.log(`[CloudFunction] Fare boosted by +₹${diff} on booking #${bookingId}`);

    // Re-broadcast incentive push to nearby workers
    await engine.broadcastNewBookingToNearbyWorkers({
      id: bookingId,
      ...afterData,
    });
  }

  // 2. Worker accepted booking (Status: pending -> accepted)
  if (oldStatus === "pending" && newStatus === "accepted") {
    const workerName = afterData.acceptedWorkerName || "Certified Artisan";
    const startOtp = afterData.startOtp || "8492";

    // Notify Customer with Start OTP & Worker Name
    if (afterData.customerId) {
      await engine.sendToUser(
        afterData.customerId,
        "BOOKING_ACCEPTED",
        {
          workerName,
          category: afterData.serviceType,
          startOtp,
        },
        { bookingId, startOtp, workerId: afterData.workerId }
      );
    }
  }

  // 3. Worker arrived at doorstep & verified OTP (Status: accepted -> inProgress)
  if (oldStatus === "accepted" && newStatus === "inProgress") {
    const workerName = afterData.acceptedWorkerName || "Artisan";
    if (afterData.customerId) {
      await engine.sendToUser(
        afterData.customerId,
        "JOB_STARTED_OTP_VERIFIED",
        {
          workerName,
          category: afterData.serviceType,
        },
        { bookingId }
      );
    }
  }

  // 4. Job completed with C2PA hardware photo proof (Status: inProgress -> completed)
  if (oldStatus === "inProgress" && newStatus === "completed") {
    const totalAmount = (afterData.amount || 0) + (afterData.urgencyBonus || 0);

    if (afterData.customerId) {
      await engine.sendToUser(
        afterData.customerId,
        "WORK_COMPLETED_C2PA_READY",
        {
          amount: String(totalAmount),
          category: afterData.serviceType,
        },
        { bookingId, amount: String(totalAmount) }
      );
    }
  }

  // 5. Payment completed (PaymentStatus: unpaid -> paid)
  if (beforeData.paymentStatus !== "paid" && afterData.paymentStatus === "paid") {
    const totalAmount = (afterData.amount || 0) + (afterData.urgencyBonus || 0);
    const dividend = (totalAmount * 0.05).toFixed(0);

    // Notify Customer
    if (afterData.customerId) {
      await engine.sendToUser(
        afterData.customerId,
        "PAYMENT_CONFIRMED_DIVIDEND",
        {
          amount: String(totalAmount),
          dividend: String(dividend),
        },
        { bookingId }
      );
    }

    // Notify Worker
    if (afterData.workerId) {
      const netEarnings = (totalAmount * 0.90).toFixed(0);
      await engine.sendToUser(
        afterData.workerId,
        "PAYMENT_CONFIRMED_DIVIDEND",
        {
          amount: String(netEarnings),
          dividend: String(dividend),
        },
        { bookingId }
      );
    }
  }
}

/**
 * Triggered when a worker verification stage updates
 */
async function handleWorkerVerificationUpdated(workerId, beforeData, afterData, db, messaging) {
  const engine = getEngine(db, messaging);
  const oldStage = beforeData.verificationStage;
  const newStage = afterData.verificationStage;
  const oldVisibility = beforeData.visibilityStatus;
  const newVisibility = afterData.visibilityStatus;

  console.log(`[CloudFunction] onWorkerVerificationUpdated: Worker #${workerId} stage: ${oldStage} -> ${newStage}`);

  // 1. Public certification approved
  if (oldVisibility !== "public" && newVisibility === "public") {
    const userId = afterData.userId || workerId;
    await engine.sendToUser(userId, "PCC_APPROVED_PUBLIC_LISTING", {}, { workerId });
  }

  // 2. Safety dispute suspension
  if (oldVisibility !== "suspended" && newVisibility === "suspended") {
    const userId = afterData.userId || workerId;
    await engine.sendToUser(
      userId,
      "ACCOUNT_SUSPENDED_DISPUTE",
      { bookingId: "SAFETY_DISPUTE" },
      { workerId }
    );
  }

  // 3. Stage Progression Step Approval
  if (oldStage !== newStage && newStage !== "rejected") {
    const stageTitles = {
      aadhaarOfflineEkyc: "Aadhaar eKYC",
      onDeviceLiveness: "Liveness Check",
      liveVideoVerification: "Video KYC",
      pccUpload: "Police Clearance Intake",
      approved: "Full Co-op Certification",
    };

    const stageTitle = stageTitles[newStage] || newStage;
    const userId = afterData.userId || workerId;
    await engine.sendToUser(userId, "KYC_STAGE_APPROVED", { stageTitle }, { workerId, stage: newStage });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RENDER BACKGROUND LISTENER INITIALIZER
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Attach real-time Firestore listeners to execute all cloud function handlers on Render
 */
function initFirestoreNotificationListeners(db, messaging) {
  console.log("[Render CloudFunctions] Initializing real-time Firestore notification daemon...");

  // 1. Listen to Bookings collection
  db.collection("bookings").onSnapshot((snapshot) => {
    snapshot.docChanges().forEach(async (change) => {
      const doc = change.doc;
      const data = doc.data();

      if (change.type === "added") {
        // Only trigger if created in the last 60 seconds (prevents cold-start burst)
        const scheduledAt = data.scheduledAt ? data.scheduledAt.toDate() : new Date();
        const diffMs = Date.now() - scheduledAt.getTime();
        if (diffMs < 60000 && data.status === "pending") {
          await handleBookingCreated(doc.id, data, db, messaging);
        }
      }

      if (change.type === "modified") {
        // Change listener on modified bookings
        const previousDoc = change.oldIndex !== -1 ? snapshot.docs[change.oldIndex] : null;
        // In local daemon we inspect delta
        await handleBookingUpdated(doc.id, { ...data, status: "previous_check" }, data, db, messaging);
      }
    });
  });

  // 2. Listen to Workers collection for KYC and Suspension
  db.collection("workers").onSnapshot((snapshot) => {
    snapshot.docChanges().forEach(async (change) => {
      if (change.type === "modified") {
        const doc = change.doc;
        const data = doc.data();
        await handleWorkerVerificationUpdated(doc.id, {}, data, db, messaging);
      }
    });
  });

  console.log("[Render CloudFunctions] Notification background triggers active.");
}

module.exports = {
  handleBookingCreated,
  handleBookingUpdated,
  handleWorkerVerificationUpdated,
  initFirestoreNotificationListeners,
};
