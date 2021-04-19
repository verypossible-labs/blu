defmodule Blu do
  @moduledoc """
  The `Blu` module defines the public interface for the Blu library.
  """

  use Blu.Log
  use GenServer

  @type action() :: any()
  @type write_queue() :: [binary()]
  @type id() :: atom()

  @typedoc "See `t:start_link_opts()`."
  @type start_link_opt() :: {:id, id()} | {:transport, transport()}

  @typedoc """
  Options for `start_link/1`.

  ## Options

  - `:id`. Required.
  - `:transport`. Required.
  """
  @type start_link_opts() :: [start_link_opt()]

  @type num_hci_command_packets() :: num_hci_command_packets()
  @type start_link_arg() :: {:id, id()} | {:transport, transport()}
  @type start_link_args() :: [start_link_arg()]
  @type state() :: %{
          write_queue: write_queue(),
          num_hci_command_packets: num_hci_command_packets(),
          id: id()
        }
  @type transport() :: %{module: module(), opts: Keyword.t()}

  def add_num_hci_command_packets(id, count) do
    id
    |> name()
    |> GenServer.cast({:add_num_hci_command_packets, count})
  end

  @impl GenServer
  def handle_cast({:add_num_hci_command_packets, count}, state) do
    state = %{state | num_hci_command_packets: state.num_hci_command_packets + count}
    {:noreply, state}
  end

  def handle_cast({:bluetooth_packet, :acl_data, packet}, state) do
    <<2, packet::binary>>
    |> Harald.decode_acl_data()
    |> case do
      {:ok, acl_data} ->
        :ok = publish(state.id, :acl_data, acl_data)

      {:error, error} ->
        :ok = publish(state.id, {:error, :decode_acl_data}, {error, packet})
    end
  end

  def handle_cast({:bluetooth_packet, :synchronous_data, packet}, state) do
    packet
    |> Harald.decode_synchronous_data()
    |> case do
      {:ok, synchronous_data} ->
        :ok = publish(state.id, :synchronous_data, synchronous_data)

      {:error, error} ->
        :ok = publish(state.id, {:error, :decode_synchronous_data}, {error, packet})
    end
  end

  def handle_cast({:bluetooth_packet, :event, packet}, state) do
    case Harald.decode_event(packet) do
      {:ok, event} ->
        :ok = publish(state.id, :event, %{decode: :ok, event: event})

        state =
          case event.module do
            Harald.HCI.Events.CommandComplete ->
              warn(%{note: "set num to #{event.parameters.num_hci_command_packets}"})
              %{state | num_hci_command_packets: event.parameters.num_hci_command_packets}

            _ ->
              state
          end

        state = do_process_write_queue(state)

        {:noreply, state}

      {:error, error} ->
        :ok = publish(state.id, :event, %{decode: :error, error: error})
        {:noreply, state}
    end
  end

  def handle_cast(:informational_parameters, state) do
    {:ok, bin_read_bd_addr} =
      Harald.encode_command(
        Harald.HCI.Commands.InformationalParameters,
        Harald.HCI.Commands.InformationalParameters.ReadBdAddr
      )

    {:ok, bin_read_buffer_size} =
      Harald.encode_command(
        Harald.HCI.Commands.InformationalParameters,
        Harald.HCI.Commands.InformationalParameters.ReadBufferSize
      )

    {:ok, bin_read_local_supported_features} =
      Harald.encode_command(
        Harald.HCI.Commands.InformationalParameters,
        Harald.HCI.Commands.InformationalParameters.ReadLocalSupportedFeatures
      )

    state =
      [bin_read_bd_addr, bin_read_buffer_size, bin_read_local_supported_features]
      |> enqueue_writes(state)
      |> do_process_write_queue()

    {:noreply, state}
  end

  def handle_cast(:process_write_queue, state) do
    state = do_process_write_queue(state)
    {:noreply, state}
  end

  def handle_cast(:reset, state) do
    {:ok, bin_reset} =
      Harald.encode_command(
        Harald.HCI.Commands.ControllerAndBaseband,
        Harald.HCI.Commands.ControllerAndBaseband.Reset,
        %{}
      )

    state =
      [bin_reset]
      |> enqueue_writes(state)
      |> do_process_write_queue()

    {:noreply, state}
  end

  def handle_cast(:restart, state) do
    warn(%{type: :unimplemented})
    {:noreply, state}
  end

  def handle_cast({:scan, enable, filter_duplicates}, state) do
    {:ok, bin_reset} =
      Harald.encode_command(
        Harald.HCI.Commands.LEController,
        Harald.HCI.Commands.LEController.SetScanEnable,
        %{filter_duplicates: filter_duplicates, le_scan_enable: enable}
      )

    state =
      [bin_reset]
      |> enqueue_writes(state)
      |> do_process_write_queue()

    {:noreply, state}
  end

  def handle_bluetooth_packet(id, packet_type, packet) do
    id
    |> name()
    |> GenServer.cast({:bluetooth_packet, packet_type, packet})
  end

  def informational_parameters(id) do
    id
    |> name
    |> GenServer.cast(:informational_parameters)
  end

  @impl GenServer
  def init(opts) do
    transport = Keyword.fetch!(opts, :transport)
    transport_module = Keyword.fetch!(transport, :module)
    transport_opts = Keyword.fetch!(transport, :opts)
    id = Keyword.fetch!(opts, :id)

    {:ok, registry_pid} =
      Registry.start_link(
        keys: :duplicate,
        name: registry_name(id),
        partitions: System.schedulers_online()
      )

    {:ok, setup_ret} = transport_module.setup(transport_opts)

    {:ok, bin_reset} =
      Harald.encode_command(
        Harald.HCI.Commands.ControllerAndBaseband,
        Harald.HCI.Commands.ControllerAndBaseband.Reset,
        %{}
      )

    state = %{
      id: id,
      num_hci_command_packets: 2,
      registry_pid: registry_pid,
      transport: %{module: transport_module, opts: transport_opts, setup_ret: setup_ret},
      write_queue: [bin_reset, bin_reset]
    }

    warn(%{note: "num 2 in init"})

    GenServer.cast(self(), :process_write_queue)
    {:ok, state}
  end

  def name(id), do: Module.concat(Blu.BluNamespace, :"#{id}")

  def process_write_queue(id) do
    id
    |> name()
    |> GenServer.cast(:process_write_queue)
  end

  def publish(id, topic, data) do
    id
    |> registry_name()
    |> Registry.dispatch({__MODULE__, topic}, fn entries ->
      for {pid, _} <- entries, do: send(pid, {__MODULE__, topic, data})
    end)
  end

  def registry_name(id), do: Module.concat(Blu.RegistryNamespace, :"#{id}")

  def reset(id) do
    id
    |> name()
    |> GenServer.cast(:reset)
  end

  def restart(id) do
    id
    |> name()
    |> GenServer.cast(:restart)
  end

  def scan(id, enable \\ true, filter_duplicates \\ true) do
    id
    |> name()
    |> GenServer.cast({:scan, enable, filter_duplicates})
  end

  @spec start_link(start_link_opts()) :: {:ok, state()}
  def start_link(opts) do
    info(%{type: :start_link})
    id = Keyword.fetch!(opts, :id)
    transport = Keyword.fetch!(opts, :transport)
    transport_module = Keyword.fetch!(transport, :module)

    transport_opts =
      transport
      |> Keyword.fetch!(:opts)
      |> Keyword.put_new(:id, id)

    blu_opts = [id: id, transport: [module: transport_module, opts: transport_opts]]
    genserver_opts = [name: name(id)]
    GenServer.start_link(__MODULE__, blu_opts, genserver_opts)
  end

  def state(id) do
    id
    |> name()
    |> GenServer.whereis()
    |> :sys.get_state()
  end

  def subscribe(id, topics) when is_list(topics) do
    for topic <- topics, do: :ok = subscribe(id, topic)
    :ok
  end

  def subscribe(id, topic) do
    {:ok, _} = Registry.register(registry_name(id), {__MODULE__, topic}, [])
    :ok
  end

  defp enqueue_writes(bins, state) when is_list(bins) do
    Map.update!(state, :write_queue, fn write_queue -> write_queue ++ bins end)
  end

  defp do_process_write_queue(%{write_queue: []} = state), do: state

  defp do_process_write_queue(
         %{
           write_queue: [bin | write_queue],
           num_hci_command_packets: num_hci_command_packets
         } = state
       )
       when num_hci_command_packets >= 1 do
    :ok = state.transport.module.write(state.id, bin)

    state = %{
      state
      | write_queue: write_queue,
        num_hci_command_packets: num_hci_command_packets - 1
    }

    warn(%{note: "num minus 1"})

    do_process_write_queue(state)
  end

  defp do_process_write_queue(%{num_hci_command_packets: num_hci_command_packets} = state)
       when num_hci_command_packets == 0 do
    state
  end
end
