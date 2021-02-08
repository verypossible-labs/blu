# Architecture

Elixir module hierarchy.

- Blu: Top level interface.
  - Controller: Hardware interface behaviour.
    - BCM2835: Hardware interface implementation.
  - Registry: Data and event pub/sub.
  - Supervisor: Root supervisor for Blu.
  - Transport: HCI transport behavior.
    - UART: HCI transport implementation.

Blu is a library application: it does not define its own `{:mod, module()}`. However, Blu is
intended to be ran within a supervision tree via `Blu.Supervisor`.
