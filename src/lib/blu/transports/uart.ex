defmodule Blu.Transports.UART do
  @moduledoc """
  Reference: version 5.0, vol 4, part A, 1.
  """

  use Blu.Log
  use GenServer
  use Hook
  alias Harald.HCI.Packet
  alias Harald.HCI.Transport.UART.Framing

  @typedoc "See `t:setup_opts`."
  @type setup_opt() :: {:device, Path.t()}

  @typedoc """
  Options for `setup/1`.

  ## Options

  `:device` - `String.t()`. Required.
  """
  @type setup_opts() :: [setup_opt()]

  @behaviour Blu.Transports.Behaviour

  @impl GenServer
  def init(opts) do
    device = Keyword.fetch!(opts, :device)
    id = Keyword.fetch!(opts, :id)
    {:ok, pid} = Circuits.UART.start_link(name: __MODULE__.Circuits.UART)
    adapter_opts = [active: true, framing: {Framing, []}, speed: 115_200, flow_control: :none]

    case Circuits.UART.open(pid, device, adapter_opts) do
      :ok -> {:ok, %{adapter_opts: adapter_opts, id: id, uart_pid: pid}}
      {:error, _} = e -> e
    end
  end

  def name(id), do: Module.concat(__MODULE__, :"#{id}")

  @impl Blu.Transports.Behaviour
  def setup(opts) do
    with {true, :device} <- {Keyword.has_key?(opts, :device), :device} do
      name =
        opts
        |> Keyword.fetch!(:id)
        |> name()

      case GenServer.start_link(__MODULE__, opts, name: name) do
        {:ok, _} = ret -> ret
        {:error, _} = e -> e
      end
    else
      {false, :device} -> {:error, {:args, %{device: ["required"]}}}
    end
  end

  @impl GenServer
  def handle_call({:write, bin}, _from, %{uart_pid: uart_pid} = state) do
    with :ok <- Circuits.UART.write(uart_pid, bin) do
      {:reply, :ok, state}
    else
      :error -> {:reply, {:error, :circuits_uart_write}}
    end
  end

  @impl GenServer
  def handle_info({:circuits_uart, _dev, indicator_and_packet}, state) do
    event_indicator = Packet.indicator(:event)
    acl_data_indicator = Packet.indicator(:acl_data)
    synchronous_data_indicator = Packet.indicator(:synchronous_data)

    case indicator_and_packet do
      <<^acl_data_indicator, packet::binary()>> ->
        :ok = Blu.handle_bluetooth_packet(state.id, :acl_data, packet)

      <<^synchronous_data_indicator, packet::binary()>> ->
        :ok = Blu.handle_bluetooth_packet(state.id, :synchronous_data, packet)

      <<^event_indicator, packet::binary()>> ->
        :ok = Blu.handle_bluetooth_packet(state.id, :event, packet)
    end

    {:noreply, state}
  end

  @impl Blu.Transports.Behaviour
  def write(id, bin) do
    :ok =
      id
      |> name()
      |> GenServer.call({:write, bin})

    :ok
  end
end
