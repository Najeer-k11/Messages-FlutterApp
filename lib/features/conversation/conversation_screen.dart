import 'package:flutter/material.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/models/message_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/features/conversation/widgets/message_bubble.dart';
import 'package:msgs/features/conversation/widgets/composer.dart';
import 'package:msgs/core/motion/motion_engine.dart';

class ConversationScreen extends StatefulWidget {
  final ThreadModel thread;

  const ConversationScreen({super.key, required this.thread});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark thread as read as soon as conversation is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SmsRepository>().markThreadAsRead(
            widget.thread.address,
            widget.thread.nativeThreadId,
          );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    try {
      await context.read<SmsRepository>().sendSms(widget.thread.address, text);
      
      // Scroll to bottom
      _scrollController.animateTo(
        0,
        duration: MotionEngine.durationFast,
        curve: MotionEngine.curveStandard,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SMS: \$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.thread.id}',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  widget.thread.senderName.isNotEmpty ? widget.thread.senderName.substring(0, 1).toUpperCase() : '?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Hero(
                tag: 'name_${widget.thread.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    widget.thread.senderName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          // Dynamic Background using subtle theme gradients
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
                  theme.colorScheme.secondaryContainer.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
          
          Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: context.read<SmsRepository>().watchMessagesForThread(widget.thread.address),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: \${snapshot.error}'));
                    }
                    
                    final messagesList = snapshot.data ?? [];
                    
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Latest messages at the bottom
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: messagesList.length,
                      itemBuilder: (context, index) {
                        final message = messagesList[index];
                        
                        // Logic for grouping bubbles
                        bool isFirstInGroup = true;
                        bool isLastInGroup = true;
                        
                        if (index > 0) {
                          final prevMessage = messagesList[index - 1]; // "next" message visually since reversed
                          if (prevMessage.isMe == message.isMe) {
                            isLastInGroup = false;
                          }
                        }
                        if (index < messagesList.length - 1) {
                          final nextMessage = messagesList[index + 1]; // "previous" message visually
                          if (nextMessage.isMe == message.isMe) {
                            isFirstInGroup = false;
                          }
                        }

                        // For now we pass null for status since MessageModel doesn't have MessageStatus yet
                        final bubble = MessageBubble(
                          messageText: message.body,
                          isMe: message.isMe,
                          timestamp: message.timestamp,
                          isFirstInGroup: isFirstInGroup,
                          isLastInGroup: isLastInGroup,
                        );
                        
                        return bubble;
                      },
                    );
                  }
                ),
              ),
              Composer(onSend: _sendMessage),
            ],
          ),
        ],
      ),
    );
  }
}
