defmodule Accountex.System do
  use Ash.Domain,
    otp_app: :accountex

  resources do
    resource Accountex.System.ActivitySetup
  end
end
