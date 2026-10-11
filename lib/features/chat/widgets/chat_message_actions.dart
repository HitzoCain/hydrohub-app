import 'package:flutter/material.dart';

const chatReactionOptions = ['👍', '❤️', '😂', '😮', '😢'];

Map<String, String> parseChatReactions(dynamic value) {
  if (value is! Map) return const {};

  return value.map(
    (key, reaction) => MapEntry(key.toString(), reaction.toString()),
  );
}

class ChatMessageAction {
  const ChatMessageAction({this.reaction, this.edit = false});

  final String? reaction;
  final bool edit;
}

Future<ChatMessageAction?> showChatMessageActions(
  BuildContext context, {
  required bool canEdit,
  required String? selectedReaction,
}) {
  return showModalBottomSheet<ChatMessageAction>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'React to message',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final reaction in chatReactionOptions)
                  InkWell(
                    onTap: () => Navigator.pop(
                      context,
                      ChatMessageAction(
                        reaction: selectedReaction == reaction
                            ? null
                            : reaction,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedReaction == reaction
                            ? const Color(0xFFDBEAFE)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        reaction,
                        style: const TextStyle(fontSize: 21),
                      ),
                    ),
                  ),
              ],
            ),
            if (canEdit) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () =>
                    Navigator.pop(context, const ChatMessageAction(edit: true)),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Future<String?> showEditChatMessageDialog(
  BuildContext context, {
  required String initialText,
}) async {
  final controller = TextEditingController(text: initialText);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit message'),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 1,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Message'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

class ChatReactionBadges extends StatelessWidget {
  const ChatReactionBadges({
    super.key,
    required this.reactions,
    required this.actorId,
  });

  final Map<String, String> reactions;
  final String actorId;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final reaction in reactions.values) {
      counts.update(reaction, (count) => count + 1, ifAbsent: () => 1);
    }

    if (counts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Wrap(
        spacing: 5,
        children: [
          for (final entry in counts.entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: reactions[actorId] == entry.key
                    ? Border.all(color: const Color(0xFF93C5FD))
                    : null,
              ),
              child: Text(
                '${entry.key} ${entry.value > 1 ? entry.value : ''}'.trim(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
