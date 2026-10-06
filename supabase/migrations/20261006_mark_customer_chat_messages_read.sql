CREATE OR REPLACE FUNCTION public.mark_customer_conversation_read(
  p_conversation_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  updated_count integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.conversations AS conversation
    WHERE conversation.id = p_conversation_id
      AND (
        conversation.customer_id::text = auth.uid()::text
        OR conversation.participant_id::text = auth.uid()::text
      )
  ) THEN
    RAISE EXCEPTION 'Conversation not found or not owned by customer';
  END IF;

  UPDATE public.messages AS message
  SET is_read = true
  WHERE message.conversation_id = p_conversation_id
    AND lower(message.sender_type) IN ('driver', 'admin')
    AND message.is_read = false;

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN updated_count;
END;
$function$;

REVOKE ALL ON FUNCTION public.mark_customer_conversation_read(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_customer_conversation_read(uuid)
  TO authenticated;