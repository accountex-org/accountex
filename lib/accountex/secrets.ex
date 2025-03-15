defmodule Accountex.Secrets do
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Accountex.Accounts.User, _opts) do
    Application.fetch_env(:accountex, :token_signing_secret)
  end
end
