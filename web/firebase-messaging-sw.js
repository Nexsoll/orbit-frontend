/* Firebase Messaging SW for web push notifications */
/* eslint-disable no-undef */

importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBajx0oj_JPE3hEZ4DvTh1PmZvRptUe0Xo',
  appId: '1:507943861710:web:d27274ff625b3592733f9f',
  messagingSenderId: '507943861710',
  projectId: 'orbit-fc910',
  authDomain: 'orbit-fc910.firebaseapp.com',
  storageBucket: 'orbit-fc910.firebasestorage.app',
  measurementId: 'G-XJ9SK9FHJP',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  const notificationTitle = (payload.notification && payload.notification.title) || 'Notification';
  const notificationOptions = {
    body: (payload.notification && payload.notification.body) || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
