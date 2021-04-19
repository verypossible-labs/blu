# Usage

```bash
# lookup the latest version to add to your Mix file
mix hex.info blu
> An Elixir Bluetooth Host library.
>
> Config: {:blu, "~> 0.1.0"}
> Releases: 0.1.0
>
> Licenses: MIT
> Links:
>   GitHub: https://github.com/verypossible-labs/blu
```

## Examples

Read and write local name:

```elixir
alias Harald.HCI.Commands.ControllerAndBaseband.{ReadLocalName, WriteLocalName}
{:ok, pid} = Blu.start_link(id: :bt, adapter: Blu.Transport.UART)
:ok = Blu.subscribe(:bt, [:events])
{:ok, bin_read_local_name} = Blu.encode(ReadLocalName)
:ok = Blu.write(:bt, bin_read_local_name)
# controller is processing command
flush()
# received command complete event, note the name
{:ok, bin_write_local_name} = Blu.encode(WriteLocalName, %{local_name: "new-name"})
:ok = Blu.write(:bt, bin_write_local_name)
# controller is processing command
flush()
# received command complete event
:ok = Blu.write(:bt, bin_read_local_name)
# controller is processing command
flush()
# received command complete event, note the changed name
```
