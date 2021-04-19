defmodule Blue.Controllers.BCM2835 do
  @moduledoc """
  Support for Broadcom's BCM2835 SoC.

  Support for this SoC is verified against the [Raspberry PI Zero W](https://www.raspberrypi.org/products/raspberry-pi-zero-w/).

  Reference: https://www.raspberrypi.org/documentation/hardware/raspberrypi/bcm2835/BCM2835-ARM-Peripherals.pdf
  """

  @behaviour Controllers

  @impl Controllers
  def restart(id) do
    :ok
  end
end
