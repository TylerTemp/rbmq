defmodule RBMQ.Consumer do
  @moduledoc """
  AMQP channel consumer.

  TODO: take look at genevent and defimpl Stream (use as Stream) for consumers.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use RBMQ.GenQueue, opts

      def init_worker(chan, opts) do
        link_consumer(chan, opts[:queue][:name], Keyword.get(opts, :options, []))
        chan
      end

      defp link_consumer(chan, queue_name, options) do
        normalized_options =
          if Keyword.has_key?(options, :durable) do
            {persistent, clean_options} = Keyword.pop(options, :durable)
            Keyword.put(clean_options, :persistent, persistent)
          else
            options
          end

        safe_run(fn chan ->
          {:ok, _consumer_tag} = AMQP.Basic.consume(chan, queue_name, nil, normalized_options)
          Process.monitor(chan.pid)
        end)
      end

      @doc false
      def handle_info({:DOWN, monitor_ref, :process, pid, reason}, state) do
        Process.demonitor(monitor_ref)
        config = chan_config()
        state = link_consumer(nil, config[:queue][:name], Keyword.get(config, :options, []))
        {:noreply, state}
      end

      # Confirmation sent by the broker after registering this process as a consumer
      def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
        {:noreply, state}
      end

      # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
      def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
        {:stop, :shutdown, state}
      end

      # Confirmation sent by the broker to the consumer process after a Basic.cancel
      def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
        {:stop, :normal, state}
      end

      # Handle new message delivery
      def handle_info(
            {:basic_deliver, payload, basic_properties},
            state
          ) do
        consume(payload, basic_properties)
        {:noreply, state}
      end

      def ack(tag) do
        safe_run(fn chan ->
          AMQP.Basic.ack(chan, tag)
        end)
      end

      def nack(tag) do
        safe_run(fn chan ->
          AMQP.Basic.nack(chan, tag)
        end)
      end

      def cancel(tag) do
        safe_run(fn chan ->
          AMQP.Basic.cancel(chan, tag)
        end)
      end

      def consume(_payload, %{tag: tag, redelivered?: _redelivered, channel: chan}) do
        # Mark this message as unprocessed
        nack(tag)
        # Stop consumer from receiving more messages
        cancel(tag)
        raise "#{__MODULE__}.consume/2 is not implemented"
      end

      defoverridable consume: 2
    end
  end

  @doc """
  Receiver of messages.

  If channel is down it will keep trying to send message with 3 second timeout.
  """
  @callback consume :: :ok | :error
end
