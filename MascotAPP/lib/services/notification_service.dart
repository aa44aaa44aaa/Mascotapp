import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendLikeNotification(
      String postId, String senderId, String recipientId) async {
    final notificationRef = _firestore.collection('notifications');

    final existingLikeNotification = await notificationRef
        .where('recipient', isEqualTo: recipientId)
        .where('sender', isEqualTo: senderId)
        .where('postId', isEqualTo: postId)
        .where('type', isEqualTo: 'like')
        .limit(1)
        .get();

    if (existingLikeNotification.docs.isEmpty) {
      await notificationRef.add({
        'recipient': recipientId,
        'type': 'like',
        'postId': postId,
        'sender': senderId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> sendCommentNotification(
      String postId, String senderId, String recipientId) async {
    final notificationRef = _firestore.collection('notifications');

    final existingCommentNotification = await notificationRef
        .where('recipient', isEqualTo: recipientId)
        .where('sender', isEqualTo: senderId)
        .where('postId', isEqualTo: postId)
        .where('type', isEqualTo: 'comment')
        .limit(1)
        .get();

    if (existingCommentNotification.docs.isEmpty) {
      await notificationRef.add({
        'recipient': recipientId,
        'type': 'comment',
        'postId': postId,
        'sender': senderId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> sendCustomNotification(
      String text, String icon, String recipientId) async {
    final notificationRef = _firestore.collection('notifications');

    final existingCustomNotification = await notificationRef
        .where('recipient', isEqualTo: recipientId)
        .where('text', isEqualTo: text)
        .where('icon', isEqualTo: icon)
        .where('type', isEqualTo: 'custom')
        .limit(1)
        .get();

    if (existingCustomNotification.docs.isEmpty) {
      await notificationRef.add({
        'recipient': recipientId,
        'type': 'custom',
        'icon': icon,
        'text': text,
        'postId': 'none',
        'sender': 'rdiY6ho9PJfnUQ8VSCV2hrRZ2Gu1',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> sendFanNotification(String recipientId, String text,
      String mascotaId, String senderId) async {
    final notificationRef = _firestore.collection('notifications');

    final existingCustomNotification = await notificationRef
        .where('recipient', isEqualTo: recipientId)
        .where('senderId', isEqualTo: senderId)
        .where('text', isEqualTo: text)
        .where('type', isEqualTo: 'fan')
        .limit(1)
        .get();

    if (existingCustomNotification.docs.isEmpty) {
      await notificationRef.add({
        'recipient': recipientId,
        'type': 'fan',
        'text': text,
        'MascotaId': mascotaId,
        'sender': senderId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }
}
