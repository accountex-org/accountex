defmodule Accountex.Accounts do
  use Ash.Domain, otp_app: :accountex, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Accountex.Accounts.Token
    resource Accountex.Accounts.User
  end
end
