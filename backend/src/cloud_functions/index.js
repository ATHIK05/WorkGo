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

  // 3. Worker arrived at doorstep
  if (oldStatus !== "arrived" && newStatus === "arrived") {
    const workerName = afterData.acceptedWorkerName || "Artisan";
    const startOtp = afterData.startOtp || "";
    if (afterData.customerId) {
      await engine.sendToUser(
        afterData.customerId,
        "WORKER_ARRIVED_DOORSTEP",
        {
          workerName,
          startOtp,
        },
        { bookingId, startOtp }
      );
    }
  }

  // 4. Worker verified OTP & started work (Status: accepted/arrived -> inProgress)
  if ((oldStatus === "accepted" || oldStatus === "arrived") && newStatus === "inProgress") {
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

  // 5. Job completed with C2PA hardware photo proof (Status: inProgress -> completed)
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

  // 6. Booking cancelled (Status -> cancelled)
  if (oldStatus !== "cancelled" && newStatus === "cancelled") {
    const cancelledBy = afterData.cancelledBy || "customer";
    const reason = afterData.cancellationReason || "No reason specified";

    if (cancelledBy === "customer") {
      // Check if assigned to a dial worker
      let isDial = afterData.isAssignedToDialWorker === true || !!afterData.dialWorkerPhone;
      if (!isDial && afterData.workerId && db) {
        try {
          const wDoc = await db.collection("workers").doc(afterData.workerId).get();
          if (wDoc.exists && wDoc.data()?.isDialWorker === true) {
            isDial = true;
          }
        } catch (_) {}
      }

      if (isDial) {
        // Dial worker: Outbound robocall with Bhashini TTS (trade, location, time logic, reason)
        await engine.notifyDialWorkerBookingCancelled({
          id: bookingId,
          ...afterData,
        });
      } else if (afterData.workerId) {
        // Smartphone worker: FCM Push Notification
        await engine.sendToUser(
          afterData.workerId,
          "BOOKING_CANCELLED_BY_CUSTOMER",
          {
            bookingId,
            reason,
          },
          { bookingId, reason }
        );
      }

      // Abort any in-progress alert robocalls for this booking
      try {
        const { abortCallBookingCancelled } = require("../services/voice_call_engine");
        await abortCallBookingCancelled(bookingId);
      } catch (_) {}
    } else if (cancelledBy === "worker" && afterData.customerId) {
      // Notify Customer that artisan cancelled
      await engine.sendToUser(
        afterData.customerId,
        "BOOKING_CANCELLED_BY_WORKER",
        {
          bookingId,
          reason,
        },
        { bookingId, reason }
      );
    }
  }

  // 7. Payment completed (PaymentStatus: unpaid -> paid)
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

  const lastBookingCache = new Map();
  const lastWorkerCache = new Map();
  let isInitialBookingsLoad = true;
  let isInitialWorkersLoad = true;

  // 1. Listen to Bookings collection
  db.collection("bookings").onSnapshot(
    (snapshot) => {
      snapshot.docChanges().forEach(async (change) => {
        const doc = change.doc;
        const data = doc.data();

        if (change.type === "added") {
          if (isInitialBookingsLoad) {
            // Cold-start seed without firing notifications
            lastBookingCache.set(doc.id, data);
          } else {
            // Newly created booking while server is running
            lastBookingCache.set(doc.id, data);
            if (data.status === "pending") {
              await handleBookingCreated(doc.id, data, db, messaging);
            }
          }
        } else if (change.type === "modified") {
          const beforeData = lastBookingCache.get(doc.id) || {};
          lastBookingCache.set(doc.id, data);
          await handleBookingUpdated(doc.id, beforeData, data, db, messaging);
        } else if (change.type === "removed") {
          lastBookingCache.delete(doc.id);
        }
      });
      isInitialBookingsLoad = false;
    },
    (err) => {
      console.error("[Render CloudFunctions] Bookings listener error:", err.message);
    }
  );

  // 2. Listen to Workers collection for KYC and Suspension
  db.collection("workers").onSnapshot(
    (snapshot) => {
      snapshot.docChanges().forEach(async (change) => {
        const doc = change.doc;
        const data = doc.data();

        if (change.type === "added") {
          lastWorkerCache.set(doc.id, data);
        } else if (change.type === "modified") {
          const beforeData = lastWorkerCache.get(doc.id) || {};
          lastWorkerCache.set(doc.id, data);
          await handleWorkerVerificationUpdated(doc.id, beforeData, data, db, messaging);
        } else if (change.type === "removed") {
          lastWorkerCache.delete(doc.id);
        }
      });
      isInitialWorkersLoad = false;
    },
    (err) => {
      console.error("[Render CloudFunctions] Workers listener error:", err.message);
    }
  );

  console.log("[Render CloudFunctions] Notification background triggers active.");
}

module.exports = {
  handleBookingCreated,
  handleBookingUpdated,
  handleWorkerVerificationUpdated,
  initFirestoreNotificationListeners,
};
