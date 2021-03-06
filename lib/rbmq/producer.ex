defmodule RBMQ.Producer do
  @moduledoc """
  AMQP channel producer.

  You must configure connection (queue and exchange) before calling `publish/1` function.
  """

  @doc false
  defmacro __using__(opts) do
    alias AMQP.Basic

    quote bind_quoted: [opts: opts] do
      use RBMQ.GenQueue, opts

      def validate_config!(conf) do
        unless conf[:queue][:routing_key] do
          raise "You need to set queue routing key in #{__MODULE__} options."
        end

        err_msg = "Queue routing key for #{__MODULE__} must be a string or env link, given: "
        validate_conf_value(conf[:queue][:routing_key], err_msg)

        unless conf[:exchange] do
          raise "You need to configure exchange in #{__MODULE__} options."
        end

        unless conf[:exchange][:name] do
          raise "You need to set exchange name in #{__MODULE__} options."
        end

        err_msg = "Exchange name key for #{__MODULE__} must be a string or env link, given: "
        validate_conf_value(conf[:exchange][:name], err_msg)

        unless conf[:exchange][:type] do
          raise "You need to set exchange name in #{__MODULE__} options."
        end

        unless conf[:exchange][:type] in [:direct, :fanout, :topic, :headers] do
          raise "Incorrect exchange type in #{__MODULE__} options."
        end

        conf
      end

      defp validate_conf_value({:system, _, _}, _err_msg), do: :ok
      defp validate_conf_value({:system, _}, _err_msg), do: :ok
      defp validate_conf_value(str, _err_msg) when is_binary(str), do: :ok

      defp validate_conf_value(unknown, err_msg), do: raise(err_msg <> "'#{inspect(unknown)}'.")

      @doc """
      Publish new message to a linked channel.
      """
      def publish(data, extra_options \\ []) do
        GenServer.call(__MODULE__, {:publish, {data, extra_options}}, :infinity)
      end

      @doc false
      def handle_call({:publish, {data, extra_options}}, _from, chan) do
        safe_publish(chan, data, extra_options)
      end

      defp safe_publish(chan, data, extra_options \\ []) do
        safe_run(fn chan ->
          cast(chan, data, extra_options)
        end)
      end

      defp cast(chan, data, extra_options \\ []) do
        conf = chan_config()

        is_persistent = Keyword.get(conf[:queue], :durable, false)

        options =
          [
            mandatory: true,
            persistent: is_persistent
          ] ++ extra_options

        case Basic.publish(
               chan,
               conf[:exchange][:name],
               conf[:queue][:routing_key],
               data,
               options
             ) do
          :ok ->
            {:reply, :ok, chan}

          _ ->
            {:reply, :error, chan}
        end
      end

      defoverridable validate_config!: 1
    end
  end

  @doc """
  Publish new message to a linked channel.

  If channel is down it will keep trying to send message with 3 second timeout.
  """
  @callback publish :: :ok | :error
end
