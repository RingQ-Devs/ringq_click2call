importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyC-m5DNi05l__IapZMU0Zza06eQ2j4qfow",
  authDomain: "ringq-e2c62.firebaseapp.com",
  projectId: "ringq-e2c62",
  storageBucket: "ringq-e2c62.appspot.com",
  messagingSenderId: "206198686141",
  appId: "1:206198686141:web:d7b33e45d33af3c53a92d4",
  measurementId: "G-D13VRL18GB"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("📩 Background Message Received:", payload); 

  self.registration.showNotification(payload.data?.nameCaller || "New Notification", {
    body: payload.data?.caller_id || "You have a new message.",
    icon: "/cloudapp/favicon.png",
    requireInteraction: true,
    data: { 
      url: 'https://' + payload.data?.domain,
      callId: payload.data?.callId || null,
    },
    actions: [
      // { action: "answer", title: "✅ Answer" },
      // { action: "decline", title: "❌ Decline" }
    ],
  });
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  if (event.action === "decline") {
    console.log("❌ Call declined. No action taken.");
    return;
  }

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      let clientFound = false;
 
      clientList.forEach((client) => {
        if (client.url.startsWith(event.notification.data.url) && "focus" in client) {
          client.postMessage({
            type: "NOTIFICATION_CLICKED",
            data: event.notification.data,
          });
          client.focus();
          clientFound = true;
        }
      });
 
      if (!clientFound) {
        return clients.openWindow(event.notification.data.url);
      }
    })
  );
});